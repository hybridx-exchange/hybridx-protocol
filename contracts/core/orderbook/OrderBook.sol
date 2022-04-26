// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../deps/interfaces/IERC20.sol";
import "../../deps/interfaces/IWETH.sol";
import "../../deps/libraries/UQ112x112.sol";
import '../../deps/libraries/TransferHelper.sol';
import "../../deps/libraries/Arrays.sol";
import "./interfaces/IOrderBook.sol";
import "./libraries/OrderBookLibrary.sol";
import "./OrderQueue.sol";
import "./PriceList.sol";

contract OrderBook is IOrderBook, OrderQueue, PriceList {
    using SafeMath for uint;
    using SafeMath for uint112;
    using UQ112x112 for uint224;

    struct Order {
        address owner;
        address to;
        uint orderId;
        uint price;
        uint amountOffer;
        uint amountRemain;
        uint orderType; //1: limitBuy, 2: limitSell
        uint orderIndex; //用户订单索引，一个用户最多255
    }

    bytes4 private constant SELECTOR_TRANSFER = bytes4(keccak256(bytes('transfer(address,uint256)')));

    //名称
    string public constant name = 'HybridX OrderBook';

    //order book factory
    address public factory;

    //货币对
    address public override pair;

    //order NFT
    address public orderNFT;

    //基准代币小数点位数，用于通过价格计算数量
    uint public override baseDecimal;

    //基础货币
    address public override baseToken;
    //记价货币
    address public override quoteToken;

    //基础货币余额
    uint public baseBalance;
    //计价货币余额
    uint public quoteBalance;

    //protocol fee rate (按交易量百分比收取，对应万分之x)
    uint public override protocolFeeRate;

    //subsidy fee rate (从协议费用中抽取一部分用于补贴吃单方，对应protocolFeeRate * x%)
    uint public override subsidyFeeRate;

    //未完成总订单，链上不保存已成交的订单(订单id -> Order)
    mapping(uint => Order) public marketOrders;

    //用户订单(用户地址 -> 订单id数组)
    mapping(address => uint[]) public override userOrders;

    receive() external payable {
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(
        address _pair,
        address _baseToken,
        address _quoteToken,
        address _orderNFT)
    override
    external {
        require(msg.sender == factory, 'FORBIDDEN'); // sufficient check
        (address token0, address token1) = (IPair(_pair).token0(), IPair(_pair).token1());
        require(
            (token0 == _baseToken && token1 == _quoteToken) ||
            (token1 == _baseToken && token0 == _quoteToken),
            'Token Pair Invalid');

        pair = _pair;
        orderNFT = _orderNFT;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        baseDecimal = IERC20(_baseToken).decimals();
        protocolFeeRate = 30; // 30/10000
        subsidyFeeRate = 50; // protocolFeeRate * 50%
    }

    function reverse() external override {
        require(priceLength(LIMIT_BUY) == 0 && priceLength(LIMIT_SELL) == 0,
            'Order Exist');
        (baseToken, quoteToken) = (quoteToken, baseToken);
        baseDecimal = IERC20(baseToken).decimals();
    }

    function _getBaseBalance() internal view returns (uint balance) {
        balance = IERC20(baseToken).balanceOf(address(this));
    }

    function _getQuoteBalance() internal view returns (uint balance) {
        balance = IERC20(quoteToken).balanceOf(address(this));
    }

    function _updateBalance() internal {
        baseBalance = IERC20(baseToken).balanceOf(address(this));
        quoteBalance = IERC20(quoteToken).balanceOf(address(this));
    }

    function _safeTransfer(address token, address to, uint value)
    internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR_TRANSFER, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

    function _batchTransfer(address token, address[] memory accounts, uint[] memory amounts) internal {
        address WETH = IOrderBookFactory(factory).WETH();
        for(uint i=0; i<accounts.length; i++) {
            if (WETH == token){
                IWETH(WETH).withdraw(amounts[i]);
                TransferHelper.safeTransferETH(accounts[i], amounts[i]);
            }
            else {
                _safeTransfer(token, accounts[i], amounts[i]);
            }
        }
    }

    function _singleTransfer(address token, address to, uint amount) internal {
        address WETH = IOrderBookFactory(factory).WETH();
        if (token == WETH) {
            IWETH(WETH).withdraw(amount);
            TransferHelper.safeTransferETH(to, amount);
        }
        else{
            _safeTransfer(token, to, amount);
        }
    }

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getUserOrders(address user) external override view returns (uint[] memory orderIds) {
        orderIds = userOrders[user];
    }

    function getPrice()
    public
    override
    view
    returns (uint price) {
        (uint112 reserveBase, uint112 reserveQuote) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
        if (reserveBase != 0) {
            price = reserveQuote.mul(10 ** baseDecimal) / reserveBase;
        }
    }

    function priceDecimal()
    public
    override
    view
    returns (uint decimal) {
        decimal = IERC20(quoteToken).decimals();
    }

    function tradeDirection(address tokenIn)
    internal
    view
    returns (uint direction) {
        direction = quoteToken == tokenIn ? LIMIT_BUY : LIMIT_SELL;
    }

    //添加order对象
    function _addLimitOrder(
        address user,
        address _to,
        uint _amountOffer,
        uint _amountRemain,
        uint _price,
        uint _type)
    internal
    returns (uint orderId) {
        uint[] memory _userOrders = userOrders[user];
        require(_userOrders.length < 0xff, 'Order Number is exceeded');
        uint orderIndex = _userOrders.length;

        Order memory order = Order(
            user,
            _to,
            1,
            _price,
            _amountOffer,
            _amountRemain,
            _type,
            orderIndex);
        userOrders[user].push(order.orderId);

        marketOrders[order.orderId] = order;
        if (length(_type, _price) == 0) {
            addPrice(_type, _price);
        }

        push(_type, _price, order.orderId);

        return order.orderId;
    }

    //删除order对象
    function _removeFrontLimitOrderOfQueue(Order memory order) internal {
        // pop order from queue of same price
        pop(order.orderType, order.price);
        // delete order from market orders
        delete marketOrders[order.orderId];

        // delete user order
        uint userOrderSize = userOrders[order.owner].length;
        require(userOrderSize > order.orderIndex, 'invalid orderIndex');
        //overwrite the current element with the last element directly
        uint lastUsedOrder = userOrders[order.owner][userOrderSize - 1];
        userOrders[order.owner][order.orderIndex] = lastUsedOrder;
        //update moved order's index
        marketOrders[lastUsedOrder].orderIndex = order.orderIndex;
        // delete the last element of user order list
        userOrders[order.owner].pop();

        //delete price
        if (length(order.orderType, order.price) == 0){
            delPrice(order.orderType, order.price);
        }
    }

    //删除order对象
    function _removeLimitOrder(Order memory order) internal {
        //删除队列订单
        del(order.orderType, order.price, order.orderId);
        //删除全局订单
        delete marketOrders[order.orderId];

        // delete user order
        uint userOrderSize = userOrders[order.owner].length;
        require(userOrderSize > order.orderIndex, 'invalid orderIndex');
        //overwrite the current element with the last element directly
        uint lastUsedOrder = userOrders[order.owner][userOrderSize - 1];
        userOrders[order.owner][order.orderIndex] = lastUsedOrder;
        //update moved order's index
        marketOrders[lastUsedOrder].orderIndex = order.orderIndex;
        // delete the last element of user order list
        userOrders[order.owner].pop();

        //删除价格
        if (length(order.orderType, order.price) == 0){
            delPrice(order.orderType, order.price);
        }
    }

    // list
    function list(
        uint direction,
        uint price)
    internal
    view
    returns (uint[] memory allData) {
        (uint front, uint rear) = (limitOrderQueueFront[direction][price], limitOrderQueueRear[direction][price]);
        if (front < rear){
            allData = new uint[](rear - front);
            for (uint i=front; i<rear; i++) {
                allData[i-front] = marketOrders[limitOrderQueueMap[direction][price][i]].amountRemain;
            }
        }
    }

    // listAgg
    function listAgg(
        uint direction,
        uint price)
    internal
    view
    returns (uint dataAgg) {
        (uint front, uint rear) = (limitOrderQueueFront[direction][price], limitOrderQueueRear[direction][price]);
        for (uint i=front; i<rear; i++){
            dataAgg += marketOrders[limitOrderQueueMap[direction][price][i]].amountRemain;
        }
    }

    // total amount
    function totalOrderAmount(uint direction)
    internal
    view
    returns (uint amount)
    {
        uint curPrice = nextPrice(direction, 0);
        while(curPrice != 0){
            amount += listAgg(direction, curPrice);
            curPrice = nextPrice(direction, curPrice);
        }
    }

    //订单薄，不关注订单具体信息，只用于查询
    function marketBook(
        uint direction,
        uint32 maxSize)
    external
    override
    view
    returns (uint[] memory prices, uint[] memory amounts) {
        uint priceLength = priceLength(direction);
        priceLength =  priceLength > maxSize ? maxSize : priceLength;
        prices = new uint[](priceLength);
        amounts = new uint[](priceLength);
        uint curPrice = nextPrice(direction, 0);
        uint32 index = 0;
        while(curPrice != 0 && index < priceLength){
            prices[index] = curPrice;
            amounts[index] = listAgg(direction, curPrice);
            curPrice = nextPrice(direction, curPrice);
            index++;
        }
    }

    //获取某个价格内的订单薄
    function rangeBook(uint direction, uint price)
    external
    override
    view
    returns (uint[] memory prices, uint[] memory amounts) {
        uint curPrice = nextPrice(direction, 0);
        uint priceLength;
        if (direction == LIMIT_BUY) {
            while(curPrice != 0 && curPrice >= price){
                curPrice = nextPrice(direction, curPrice);
                priceLength++;
            }
        }
        else if (direction == LIMIT_SELL) {
            while(curPrice != 0 && curPrice <= price){
                curPrice = nextPrice(direction, curPrice);
                priceLength++;
            }
        }

        if (priceLength > 0) {
            prices = new uint[](priceLength);
            amounts = new uint[](priceLength);
            curPrice = nextPrice(direction, 0);
            uint index;
            while(index < priceLength) {
                prices[index] = curPrice;
                amounts[index] = listAgg(direction, curPrice);
                curPrice = nextPrice(direction, curPrice);
                index++;
            }
        }
    }

    //市场订单
    function marketOrder(
        uint orderId
    )
    external
    override
    view
    returns (uint[] memory order){
        order = new uint[](8);
        Order memory o = marketOrders[orderId];
        //order[0] = (uint)(o.owner);
        //order[1] = (uint)(o.to);
        order[2] = o.orderId;
        order[3] = o.price;
        order[4] = o.amountOffer;
        order[5] = o.amountRemain;
        order[6] = o.orderType;
        order[7] = o.orderIndex;
    }

    //用于遍历所有订单
    function nextOrder(
        uint direction,
        uint cur)
    internal
    view
    returns (uint next, uint[] memory amounts) {
        next = nextPrice(direction, cur);
        amounts = list(direction, next);
    }

    //用于遍历所有订单薄
    function nextBook(
        uint direction,
        uint cur)
    internal
    view
    returns (uint next, uint amount) {
        next = nextPrice(direction, cur);
        amount = listAgg(direction, next);
    }

    function nextBookWhenRemoveFirst(
        uint direction,
        uint cur)
    internal
    view
    returns (uint next, uint amount) {
        next = nextPriceWhenRemoveFirst(direction, cur);
        amount = listAgg(direction, next);
    }

    //Return funds that were transferred into the contract by mistake
    function safeRefund(address token, address payable to) external override lock {
        require(msg.sender == OrderBookLibrary.getAdmin(factory), "Forbidden");
        if (token == address(0)) {
            uint ethBalance = address(this).balance;
            if (ethBalance > 0) to.transfer(ethBalance);
            return;
        }

        uint balance = IERC20(token).balanceOf(address(this));
        uint refundBalance = balance;
        if (token == baseToken) {
            uint orderBalance = totalOrderAmount(LIMIT_SELL);
            refundBalance = balance > orderBalance ? balance - orderBalance : 0;
        }
        else if (token == quoteToken) {
            uint orderBalance = totalOrderAmount(LIMIT_BUY);
            refundBalance = balance > orderBalance ? balance - orderBalance : 0;
        }

        if (refundBalance > 0) _safeTransfer(token, to, refundBalance);
    }

    function getReserves()
    external
    override
    view
    returns (uint112 reserveBase, uint112 reserveQuote) {
        (reserveBase, reserveQuote) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
    }

    function _takeLimitOrder(
        uint direction,
        uint amountInOffer,
        uint amountOutWithFee,
        uint price)
    internal
    returns (address[] memory accountsTo, uint[] memory amountsTo) {
        uint amountLeft = amountOutWithFee;
        uint index;
        uint length = length(direction, price);
        address[] memory accountsAll = new address[](length);
        uint[] memory amountsOut = new uint[](length);
        while (index < length && amountLeft > 0) {
            uint orderId = peek(direction, price);
            if (orderId == 0) break;
            Order memory order = marketOrders[orderId];
            accountsAll[index] = order.to;
            uint amountTake = amountLeft > order.amountRemain ? order.amountRemain : amountLeft;
            order.amountRemain = order.amountRemain - amountTake;
            amountsOut[index] = amountTake;

            amountLeft = amountLeft - amountTake;
            if (order.amountRemain != 0) {
                marketOrders[orderId].amountRemain = order.amountRemain;
                //emit OrderUpdate(order.owner, order.to, order.price, order.amountOffer, order
                //.amountRemain, order.orderType);
                index++;
                break;
            }

            _removeFrontLimitOrderOfQueue(order);

            //emit OrderClosed(order.owner, order.to, order.price, order.amountOffer, order
            //.amountRemain, order.orderType);
            index++;
        }

        if (index > 0) {
            accountsTo = Arrays.subAddress(accountsAll, index);
            amountsTo = new uint[](index);
            require(amountsTo.length <= amountsOut.length, "Index Invalid");
            for (uint i; i<index; i++) {
                amountsTo[i] = amountInOffer.mul(amountsOut[i]).div(amountOutWithFee);
            }
        }
    }

    function _getAmountAndTake(
        uint direction,
        uint amountInOffer,
        uint price,
        uint orderAmount)
    internal
    returns (uint amountIn, uint amountOutWithFee, uint communityFee,
        address[] memory accountsTo, uint[] memory amountsTo) {
        (amountIn, amountOutWithFee, communityFee) = OrderBookLibrary.getAmountOutForTakePrice
            (direction, amountInOffer, price, baseDecimal, protocolFeeRate, subsidyFeeRate, orderAmount);
        (accountsTo, amountsTo) = _takeLimitOrder
            (OrderBookLibrary.getOppositeDirection(direction), amountIn, amountOutWithFee, price);
    }

    function _getAmountAndPay(
        address to,
        uint direction,//TRADE DIRECTION
        uint amountInOffer,
        uint price,
        uint orderAmount,
        address[] memory _accounts,
        uint[] memory _amounts)
    internal
    returns (uint amountIn, uint amountOutWithSubsidyFee, address[] memory accounts, uint[] memory amounts) {
        uint amountOutWithFee;
        uint communityFee;
        (amountIn, amountOutWithFee, communityFee, accounts, amounts) =
            _getAmountAndTake(direction, amountInOffer, price, orderAmount);
        amounts = Arrays.extendUint(amounts, _amounts);
        accounts = Arrays.extendAddress(accounts, _accounts);
        amountOutWithSubsidyFee = amountOutWithFee.sub(communityFee);

        //当token为weth时，外部调用的时候直接将weth转出
        address tokenOut = direction == LIMIT_BUY ? baseToken : quoteToken;
        _safeTransfer(tokenOut, to, amountOutWithSubsidyFee);
    }

    function _ammSwapPrice(
        address to,
        address tokenIn,
        address tokenOut,
        uint amountAmmIn,
        uint amountAmmOut)
    internal {
        _safeTransfer(tokenIn, pair, amountAmmIn);

        (uint amount0Out, uint amount1Out) = tokenOut == IPair(pair).token1() ?
            (uint(0), amountAmmOut) : (amountAmmOut, uint(0));

        address WETH = IOrderBookFactory(factory).WETH();
        if (WETH == tokenOut) {
            IPair(pair).swapOriginal(amount0Out, amount1Out, address(this), new bytes(0));
            IWETH(WETH).withdraw(amountAmmOut);
            TransferHelper.safeTransferETH(to, amountAmmOut);
        }
        else {
            IPair(pair).swapOriginal(amount0Out, amount1Out, to, new bytes(0));
        }

        IPair(pair).sync();
    }

    /*
        swap to price1 and take the order with price of price1 and
        swap to price2 and take the order with price of price2
        ......
        until all offered amount of limit order is consumed or price == target.
    */
    function _movePriceUp(
        uint amountOffer,
        uint targetPrice,
        address to)
    internal
    returns (uint amountLeft) {
        uint[] memory reserves = new uint[](4);//[reserveBase, reserveQuote, reserveBaseTmp, reserveQuoteTmp]
        (reserves[0], reserves[1]) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
        (reserves[2], reserves[3]) = (reserves[0], reserves[1]);
        bool liquidityExists = reserves[0] > 0 && reserves[1] > 0;
        uint amountAmmBase;
        uint amountAmmQuote;
        uint amountOrderBookOut;
        amountLeft = amountOffer;

        uint price = nextPrice(LIMIT_SELL, 0);
        while (price != 0 && price <= targetPrice) {
            uint amountAmmLeft = amountLeft;
            //skip if there is no liquidity in lp pool
            if (liquidityExists) {
                (amountAmmLeft, amountAmmBase, amountAmmQuote, reserves[2], reserves[3]) =
                    OrderBookLibrary.getAmountForMovePrice(LIMIT_BUY, amountLeft,
                        reserves[0], reserves[1], price, baseDecimal);
                if (amountAmmLeft == 0) {
                    amountLeft = 0; //avoid getAmountForMovePrice recalculation
                    break;
                }
            }

            uint amount = listAgg(LIMIT_SELL, price);
            //take the order of price 'price'.
            (uint amountInForTake,
            uint amountOutWithFee,
            uint communityFee,
            address[] memory accounts,
            uint[] memory amounts) = _getAmountAndTake(LIMIT_BUY, amountAmmLeft, price, amount);
            amountOrderBookOut += amountOutWithFee.sub(communityFee);
            _batchTransfer(quoteToken, accounts, amounts);

            if (amountInForTake == amountAmmLeft) {  //break if there is no amount left.
                amountLeft = 0;  //avoid getAmountForMovePrice recalculation
                break;
            } else {
                amountLeft = amountLeft.sub(amountInForTake);
            }

                price = nextPriceWhenRemoveFirst(LIMIT_SELL, price);
        }

        // send the user for take all limit order's amount.
        if (amountOrderBookOut > 0) {
            _singleTransfer(baseToken, to, amountOrderBookOut);
        }

        // swap to target price when there is no limit order less than the target price
        if (liquidityExists && amountLeft > 0 && price != targetPrice) {
            (amountLeft, amountAmmBase, amountAmmQuote, reserves[2], reserves[3]) =
            OrderBookLibrary.getAmountForMovePrice(LIMIT_BUY, amountLeft,
            reserves[0], reserves[1], targetPrice, baseDecimal);
        }

        if (amountAmmQuote > 0) {
            if (amountLeft > 0) {
                (amountLeft, amountAmmQuote,) =
                    OrderBookLibrary.getFixAmountForMovePriceUp(amountLeft, amountAmmQuote, reserves[2], reserves[3],
                        targetPrice, baseDecimal);
            }

            _ammSwapPrice(to, quoteToken, baseToken, amountAmmQuote, amountAmmBase);
            require(amountLeft == 0 || getPrice() >= targetPrice, "Buy price mismatch");
        }
    }

    /*
        swap to price1 and take the order with price of price1 and
        swap to price2 and take the order with price of price2
        ......
        until all offered amount of limit order is consumed or price == target.
    */
    function _movePriceDown(
        uint amountOffer,
        uint targetPrice,
        address to)
    internal
    returns (uint amountLeft) {
        uint[] memory reserves = new uint[](4);//[reserveBase, reserveQuote, reserveBaseTmp, reserveQuoteTmp]
        (reserves[0], reserves[1]) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
        (reserves[2], reserves[3]) = (reserves[0], reserves[1]);
        amountLeft = amountOffer;
        bool liquidityExists = reserves[0] > 0 && reserves[1] > 0;
        uint amountAmmBase;
        uint amountAmmQuote;
        uint amountOrderBookOut;

        uint price = nextPrice(LIMIT_BUY, 0);
        while (price != 0 && price >= targetPrice) {
            uint amountAmmLeft = amountLeft;
            //skip if there is no liquidity in lp pool
            if (liquidityExists) {
                (amountAmmLeft, amountAmmBase, amountAmmQuote, reserves[2], reserves[3]) =
                OrderBookLibrary.getAmountForMovePrice(LIMIT_SELL, amountLeft,
                reserves[0], reserves[1], price, baseDecimal);
                if (amountAmmLeft == 0) {
                    amountLeft = 0;  //avoid getAmountForMovePrice recalculation
                    break;
                }
            }

            uint amount = listAgg(LIMIT_BUY, price);
            //take the order of price 'price'.
            (uint amountInForTake,
            uint amountOutWithFee,
            uint communityFee,
            address[] memory accounts,
            uint[] memory amounts) = _getAmountAndTake(LIMIT_SELL, amountAmmLeft, price, amount);
            amountOrderBookOut += amountOutWithFee.sub(communityFee);
            _batchTransfer(baseToken, accounts, amounts);

            if (amountInForTake == amountAmmLeft) { //break if there is no amount left.
                amountLeft = 0;  //avoid getAmountForMovePrice recalculation
                break;
            } else {
                amountLeft = amountLeft.sub(amountInForTake);
            }

            price = nextPriceWhenRemoveFirst(LIMIT_BUY, price);
        }

        // send the user for take all limit order's amount.
        if (amountOrderBookOut > 0) {
            _singleTransfer(quoteToken, to, amountOrderBookOut);
        }

        // swap to target price when there is no limit order less than the target price
        if (liquidityExists && amountLeft > 0 && price != targetPrice) {
            (amountLeft, amountAmmBase, amountAmmQuote, reserves[2], reserves[3]) =
                OrderBookLibrary.getAmountForMovePrice(LIMIT_SELL, amountLeft,
                    reserves[0], reserves[1], targetPrice, baseDecimal);
        }

        if (amountAmmBase > 0) {
            if (amountLeft > 0) {
                (amountLeft, amountAmmBase,) =
                    OrderBookLibrary.getFixAmountForMovePriceDown(amountLeft, amountAmmBase, reserves[2], reserves[3],
                        targetPrice, baseDecimal);
            }

            _ammSwapPrice(to, baseToken, quoteToken, amountAmmBase, amountAmmQuote);
            require(amountLeft == 0 || getPrice() <= targetPrice, "sell to target failed");
        }
    }

    //limit order for buy base token with quote token
    function createBuyLimitOrder(
        address user,
        uint price,
        address to)
    external
    override
    lock
    returns (uint orderId) {
        //require(price > 0 && price % priceStep == 0, 'Price Invalid');
        require(OrderBookLibrary.getUniswapV2OrderBookFactory(factory) == factory,
            'OrderBook unconnected');

        //get input amount of quote token for buy limit order
        uint balance = _getQuoteBalance();
        uint amountOffer = balance > quoteBalance ? balance - quoteBalance : 0;
        //uint minQuoteAmount = OrderBookLibrary.getQuoteAmountWithBaseAmountAtPrice(minAmount, price, baseDecimal);
        //require(amountOffer >= minQuoteAmount, 'Amount Invalid');

        IPair(pair).skim(user);
        uint amountRemain = _movePriceUp(amountOffer, price, to);
        if (amountRemain != 0) {
            orderId = _addLimitOrder(user, to, amountOffer, amountRemain, price, LIMIT_BUY);
            //emit OrderCreated(user, to, amountOffer, amountRemain, price, LIMIT_BUY);
        }

        //update balance
        _updateBalance();
    }

    //limit order for sell base token to quote token
    function createSellLimitOrder(
        address user,
        uint price,
        address to)
    external
    override
    lock
    returns (uint orderId) {
        //require(price > 0 && (price % priceStep) == 0, 'Price Invalid');
        require(OrderBookLibrary.getUniswapV2OrderBookFactory(factory) == factory,
            'OrderBook unconnected');

        //get input amount of base token for sell limit order
        uint balance = _getBaseBalance();
        uint amountOffer = balance > baseBalance ? balance - baseBalance : 0;
        //require(amountOffer >= minAmount, 'Amount Invalid');

        IPair(pair).skim(user);
        uint amountRemain = _movePriceDown(amountOffer, price, to);
        if (amountRemain != 0) {
            orderId = _addLimitOrder(user, to, amountOffer, amountRemain, price, LIMIT_SELL);
            //emit OrderCreated(user, to, amountOffer, amountRemain, price, LIMIT_SELL);
        }

        //update balance
        _updateBalance();
    }

    function cancelLimitOrder(uint orderId) external override lock {
        Order memory o = marketOrders[orderId];
        require(o.owner == msg.sender, 'Owner Invalid');

        _removeLimitOrder(o);

        //refund
        address token = o.orderType == LIMIT_BUY ? quoteToken : baseToken;
        _singleTransfer(token, o.to, o.amountRemain);

        //update token balance
        uint balance = IERC20(token).balanceOf(address(this));
        if (o.orderType == LIMIT_BUY) quoteBalance = balance;
        else baseBalance = balance;

        //emit OrderCanceled(o.owner, o.to, o.amountOffer, o.amountRemain, o.price, o.orderType);
    }

    /*******************************************************************************************************
                                    called by uniswap v2 pair and router
     *******************************************************************************************************/
    function getAmountOutForMovePrice(address tokenIn, uint amountInOffer)
    external
    override
    view
    returns (uint amountOutGet, uint nextReserveBase, uint nextReserveQuote) {
        (uint reserveBase, uint reserveQuote) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
        uint tradeDir = tradeDirection(tokenIn);
        uint orderDir = OrderBookLibrary.getOppositeDirection(tradeDir); // 订单方向与交易方向相反
        uint amountInLeft = amountInOffer;
        amountOutGet = 0;
        (uint price, uint amount) = nextBook(orderDir, 0);
        while (price != 0) {
            //先计算pair从当前价格到price消耗amountIn的数量
            uint amountAmmLeft;
            (amountAmmLeft,,, nextReserveBase, nextReserveQuote) =
                OrderBookLibrary.getAmountForMovePrice(tradeDir, amountInLeft, reserveBase, reserveQuote, price,
                    baseDecimal);
            if (amountAmmLeft == 0) {
                break;
            }

            //计算消耗掉一个价格的挂单需要的amountIn数量
            (uint amountInForTake, uint amountOutWithFee, uint communityFee) = OrderBookLibrary.getAmountOutForTakePrice(
                tradeDir, amountAmmLeft, price, baseDecimal, protocolFeeRate, subsidyFeeRate, amount);
            amountOutGet += amountOutWithFee.sub(communityFee);
            amountInLeft = amountInLeft.sub(amountInForTake);
            if (amountInForTake == amountAmmLeft) {
                break;
            }

            (price, amount) = nextBook(orderDir, price);
        }

        if (amountInLeft > 0) {
            amountOutGet += tradeDir == LIMIT_BUY ?
            OrderBookLibrary.getAmountOut(amountInLeft, reserveQuote, reserveBase) :
            OrderBookLibrary.getAmountOut(amountInLeft, reserveBase, reserveQuote);
        }
    }

    function getAmountInForMovePrice(address tokenOut, uint amountOutOffer)
    external
    override
    view
    returns (uint amountInGet, uint nextReserveBase, uint nextReserveQuote) {
        (uint reserveBase, uint reserveQuote) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
        uint orderDir = tradeDirection(tokenOut); // 订单方向与交易方向相反
        uint tradeDir = OrderBookLibrary.getOppositeDirection(orderDir);
        uint amountOutLeft = amountOutOffer;
        amountInGet = 0;
        (uint price, uint amount) = nextBook(orderDir, 0);
        while (price != 0) {
            //先计算pair从当前价格到price消耗amountIn的数量
            uint amountAmmLeft;
            (amountAmmLeft,,, nextReserveBase, nextReserveQuote) =
                OrderBookLibrary.getAmountForMovePriceWithAmountOut(tradeDir, amountOutLeft, reserveBase, reserveQuote,
                    price, baseDecimal);
            if (amountAmmLeft == 0) {
                break;
            }

            //计算消耗掉一个价格的挂单需要的amountOut数量
            (uint amountInForTake, uint amountOutWithFee, uint communityFee) = OrderBookLibrary.getAmountInForTakePrice
                (tradeDir, amountAmmLeft, price, baseDecimal, protocolFeeRate, subsidyFeeRate, amount);
            amountInGet += amountInForTake.add(1);
            amountOutLeft = amountOutLeft.sub(amountOutWithFee.sub(communityFee));
            if (amountOutWithFee == amountAmmLeft) {
                break;
            }

            (price, amount) = nextBook(orderDir, price);
        }

        if (amountOutLeft > 0) {
            amountInGet += tradeDir == LIMIT_BUY ?
            OrderBookLibrary.getAmountIn(amountOutLeft, reserveQuote, reserveBase) :
            OrderBookLibrary.getAmountIn(amountOutLeft, reserveBase, reserveQuote);
        }
    }

    function takeOrderWhenMovePrice(address tokenIn, uint amountIn, address to)
    external
    override
    lock
    returns (uint amountOutLeft, address[] memory accounts, uint[] memory amounts) {
        //先吃单再付款，需要保证只有pair可以调用
        require(msg.sender == pair, 'invalid sender');
        uint[] memory reserves = new uint[](2);//[reserveBase, reserveQuote]
        (reserves[0], reserves[1]) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);

        //direction for tokenA swap to tokenB
        uint tradeDir = tradeDirection(tokenIn);
        uint orderDir = OrderBookLibrary.getOppositeDirection(tradeDir);

        (uint price, uint amount) = nextBook(orderDir, 0); // 订单方向与交易方向相反
        //只处理挂单，reserveIn/reserveOut只用来计算需要消耗的挂单数量和价格范围
        while (price != 0) {
        //先计算pair从当前价格到price消耗的数量
            (uint amountAmmLeft,,,,) =
            OrderBookLibrary.getAmountForMovePrice(
                tradeDir,
                amountIn,
                reserves[0],
                reserves[1],
                price,
                baseDecimal);
            if (amountAmmLeft == 0) {
                break;
            }

            //消耗掉一个价格的挂单并返回实际需要的amountIn数量
            uint amountInForTake;
            (amountInForTake,, accounts, amounts) =
                _getAmountAndPay(to, tradeDir, amountAmmLeft, price, amount, accounts, amounts);
            amountIn = amountIn.sub(amountInForTake);
            if (amountInForTake == amountAmmLeft) {
                break;
            }

            (price, amount) = nextBookWhenRemoveFirst(orderDir, price);
        }

        //更新balance
        _updateBalance();

        if (amountIn > 0) {
            amountOutLeft += tradeDir == LIMIT_BUY ?
            OrderBookLibrary.getAmountOut(amountIn, reserves[1], reserves[0]) :
            OrderBookLibrary.getAmountOut(amountIn, reserves[0], reserves[1]);
        }
    }
}