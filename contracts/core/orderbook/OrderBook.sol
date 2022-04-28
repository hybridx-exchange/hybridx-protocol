// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../deps/interfaces/IERC20.sol";
import "../../deps/interfaces/IWETH.sol";
import "../../deps/libraries/UQ112x112.sol";
import '../../deps/libraries/TransferHelper.sol';
import "../../deps/libraries/Arrays.sol";
import "./interfaces/IOrderNFT.sol";
import "./interfaces/IOrderBook.sol";
import "./libraries/OrderBookLibrary.sol";
import "./OrderQueue.sol";
import "./PriceList.sol";

contract OrderBook is IOrderBook, OrderQueue, PriceList {
    using SafeMath for uint;
    using SafeMath for uint112;
    using UQ112x112 for uint224;

    bytes4 private constant SELECTOR_TRANSFER = bytes4(keccak256(bytes('transfer(address,uint256)')));

    //order book factory
    address public override orderBookFactory;

    //pair address
    address public override pair;

    //order NFT address
    address public override orderNFT;

    //config address
    address public override config;

    //base token
    address public override baseToken;
    //quote token
    address public override quoteToken;

    //base token balance record
    uint public override baseBalance;
    //quote token balance record
    uint public override quoteBalance;

    receive() external payable {
    }

    constructor() {
        orderBookFactory = msg.sender;
    }

    // called once by the orderBookFactory at time of deployment
    function initialize(address _pair, address _baseToken, address _quoteToken, address _orderNFT, address _config)
    override external {
        require(msg.sender == orderBookFactory, 'FORBIDDEN'); // sufficient check
        (address token0, address token1) = (IPair(_pair).token0(), IPair(_pair).token1());
        require(
            (token0 == _baseToken && token1 == _quoteToken) ||
            (token1 == _baseToken && token0 == _quoteToken),
            'Token Pair Invalid');

        pair = _pair;
        orderNFT = _orderNFT;
        config = _config;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
    }

    function reverse() external override {
        require(priceLength(LIMIT_BUY) == 0 && priceLength(LIMIT_SELL) == 0,
            'Order Exist');
        (baseToken, quoteToken) = (quoteToken, baseToken);
    }

    function _getFeeRate() internal view returns (uint protocolFeeRate, uint subsidyFeeRate) {
        return (IConfig(config).protocolFeeRate(address(this)),
                IConfig(config).subsidyFeeRate(address(this)));
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

    function _safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR_TRANSFER, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

    function _batchTransfer(address token, address[] memory accounts, uint[] memory amounts) internal {
        address WETH = IConfig(config).WETH();
        for(uint i=0; i<accounts.length; i++) {
            _singleTransfer(WETH, token, accounts[i], amounts[i]);
        }
    }

    function _singleTransfer(address WETH, address token, address to, uint amount) internal {
        if (token == WETH) {
            IWETH(WETH).withdraw(amount);
            TransferHelper.safeTransferETH(to, amount);
        }
        else {
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

    function getPrice() public override view returns (uint price) {
        (uint112 reserveBase, uint112 reserveQuote) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
        price = OrderBookLibrary.getPrice(reserveBase, reserveQuote, baseDecimal());
    }

    function getReserves() external override view returns (uint112 reserveBase, uint112 reserveQuote) {
        (reserveBase, reserveQuote) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
    }

    function priceDecimal() public override view returns (uint decimal) {
        decimal = IERC20(quoteToken).decimals();
    }

    function baseDecimal() public override view returns (uint decimal) {
        decimal = IERC20(baseToken).decimals();
    }

    function priceStep(uint price) public override view returns (uint step) {
        step = IConfig(config).priceStep(address(this), price);
    }

    function getDirection(address tokenIn) internal view returns (uint tradeDir, uint orderDir) {
        tradeDir = quoteToken == tokenIn ? LIMIT_BUY : LIMIT_SELL;
        orderDir = quoteToken == tokenIn ? LIMIT_SELL : LIMIT_BUY;
    }

    //add limit order
    function _addLimitOrder(address _to, uint _offer, uint _remain, uint _price, uint _type) internal
    returns (uint orderId) {
        IOrder.OrderDetail memory order = IOrder.OrderDetail(_price, _offer, _remain, uint8(_type));
        orderId = IOrder(orderNFT).mint(order, _to);
        if (length(_type, _price) == 0) {
            addPrice(_type, _price);
        }

        push(_type, _price, orderId);
    }

    //remove limit order from front of queue
    function _removeFrontLimitOrderOfQueue(uint orderId, IOrder.OrderDetail memory order) internal {
        // pop order from queue of same price
        pop(order._type, order._price);
        // delete order from market orders
        IOrderNFT(orderNFT).burn(orderId);

        //delete price
        if (length(order._type, order._price) == 0) {
            delPrice(order._type, order._price);
        }
    }

    //remove limit order by order id
    function _removeLimitOrder(uint orderId, IOrder.OrderDetail memory order) internal {
        //remove order by id
        del(order._type, order._price, orderId);
        //remove order nft
        IOrderNFT(orderNFT).burn(orderId);

        //remove price
        if (length(order._type, order._price) == 0) {
            delPrice(order._type, order._price);
        }
    }

    // list
    function list(uint direction, uint price) internal view returns (uint[] memory allData) {
        (uint front, uint rear) = (limitOrderQueueFront[direction][price], limitOrderQueueRear[direction][price]);
        if (front < rear){
            allData = new uint[](rear - front);
            for (uint i=front; i<rear; i++) {
                allData[i-front] = IOrderNFT(orderNFT).get(limitOrderQueueMap[direction][price][i])._remain;
            }
        }
    }

    // listAgg
    function listAgg(uint direction, uint price) internal view returns (uint dataAgg) {
        (uint front, uint rear) = (limitOrderQueueFront[direction][price], limitOrderQueueRear[direction][price]);
        for (uint i = front; i < rear; i++) {
            dataAgg += IOrderNFT(orderNFT).get(limitOrderQueueMap[direction][price][i])._remain;
        }
    }

    // total amount
    function totalOrderAmount(uint direction) internal view returns (uint amount){
        uint curPrice = nextPrice(direction, 0);
        while(curPrice != 0){
            amount += listAgg(direction, curPrice);
            curPrice = nextPrice(direction, curPrice);
        }
    }

    //order book list
    function marketBook(uint direction, uint32 maxSize) external override view
    returns (uint[] memory prices, uint[] memory amounts) {
        uint priceLength = priceLength(direction);
        priceLength =  priceLength > maxSize ? maxSize : priceLength;
        prices = new uint[](priceLength);
        amounts = new uint[](priceLength);
        uint curPrice = nextPrice(direction, 0);
        uint32 index;
        while(curPrice != 0 && index < priceLength){
            prices[index] = curPrice;
            amounts[index] = listAgg(direction, curPrice);
            curPrice = nextPrice(direction, curPrice);
            index++;
        }
    }

    //order book of price range current price and target price
    function rangeBook(uint direction, uint price) external override view
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

    function nextOrder(uint direction, uint cur) internal view returns (uint next, uint[] memory amounts) {
        next = nextPrice(direction, cur);
        amounts = list(direction, next);
    }

    function nextBook(uint direction, uint cur) internal view returns (uint next, uint amount) {
        next = nextPrice(direction, cur);
        amount = listAgg(direction, next);
    }

    function nextBookWhenRemoveFirst(uint direction, uint cur) internal view returns (uint next, uint amount) {
        next = nextPriceWhenRemoveFirst(direction, cur);
        amount = listAgg(direction, next);
    }

    // Return funds that were transferred into the contract by mistake
    function safeRefund(address token, address payable to) external override lock {
        require(msg.sender == OrderBookLibrary.getOwner(orderBookFactory), "Forbidden");
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

    function _takeLimitOrder(uint direction, uint amountInOffer, uint amountOutWithFee, uint price) internal
    returns (address[] memory accountsTo, uint[] memory amountsTo) {
        uint amountLeft = amountOutWithFee;
        uint index;
        uint length = length(direction, price);
        address[] memory accountsAll = new address[](length);
        uint[] memory amountsOut = new uint[](length);
        while (index < length && amountLeft > 0) {
            uint orderId = peek(direction, price);
            if (orderId == 0) break;
            IOrderNFT.OrderDetail memory order = IOrderNFT(orderNFT).get(orderId);
            accountsAll[index] = IERC721(orderNFT).ownerOf(orderId);
            uint amountTake = amountLeft > order._remain ? order._remain : amountLeft;
            amountsOut[index] = amountTake;

            amountLeft = amountLeft - amountTake;
            if (amountTake != order._remain) {
                IOrderNFT(orderNFT).sub(orderId, amountTake);
                index++;
                break;
            }

            _removeFrontLimitOrderOfQueue(orderId, order);
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

    function _getAmountAndTake(uint direction, uint amountInOffer, uint price, uint orderAmount) internal
    returns (uint amountIn, uint amountOutWithFee, uint communityFee,
        address[] memory accountsTo, uint[] memory amountsTo) {
        (uint protocolFeeRate, uint subsidyFeeRate) = _getFeeRate();
        (amountIn, amountOutWithFee, communityFee) = OrderBookLibrary.getAmountOutForTakePrice
            (direction, amountInOffer, price, baseDecimal(), protocolFeeRate, subsidyFeeRate, orderAmount);
        (accountsTo, amountsTo) = _takeLimitOrder
            (OrderBookLibrary.getOppositeDirection(direction), amountIn, amountOutWithFee, price);
    }

    function _getAmountAndPay(address to, uint tradeDir, uint amountInOffer, uint price, uint orderAmount,
        address[] memory _accounts, uint[] memory _amounts) internal
    returns (uint amountIn, uint amountOutWithSubsidyFee, address[] memory accounts, uint[] memory amounts) {
        uint amountOutWithFee;
        uint communityFee;
        (amountIn, amountOutWithFee, communityFee, accounts, amounts) =
            _getAmountAndTake(tradeDir, amountInOffer, price, orderAmount);
        amounts = Arrays.extendUint(amounts, _amounts);
        accounts = Arrays.extendAddress(accounts, _accounts);
        amountOutWithSubsidyFee = amountOutWithFee.sub(communityFee);

        //send eth when token is weth
        address tokenOut = tradeDir == LIMIT_BUY ? baseToken : quoteToken;
        _safeTransfer(tokenOut, to, amountOutWithSubsidyFee);
    }

    function _ammSwapPrice(address to, address tokenIn, address tokenOut, uint amountAmmIn, uint amountAmmOut)
    internal {
        _safeTransfer(tokenIn, pair, amountAmmIn);

        (uint amount0Out, uint amount1Out) = tokenOut == IPair(pair).token1() ?
            (uint(0), amountAmmOut) : (amountAmmOut, uint(0));

        address WETH = IConfig(config).WETH();
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
    function _movePriceUp(uint amountOffer, uint targetPrice, address to) internal returns (uint amountLeft) {
        uint[] memory reserves = new uint[](4);//[reserveBase, reserveQuote, reserveBaseTmp, reserveQuoteTmp]
        (reserves[0], reserves[1]) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
        (reserves[2], reserves[3]) = (reserves[0], reserves[1]);
        uint decimal = baseDecimal();
        uint amountAmmBase;
        uint amountAmmQuote;
        uint amountOrderBookOut;
        amountLeft = amountOffer;

        uint price = nextPrice(LIMIT_SELL, 0);
        while (price != 0 && price <= targetPrice) {
            uint amountAmmLeft = amountLeft;
            //skip if there is no liquidity in lp pool
            if (reserves[0] > 0 && reserves[1] > 0) {
                (amountAmmLeft, amountAmmBase, amountAmmQuote, reserves[2], reserves[3]) =
                    OrderBookLibrary.getAmountForMovePrice(LIMIT_BUY, amountLeft,
                        reserves[0], reserves[1], price, decimal);
                if (amountAmmLeft == 0) {
                    amountLeft = 0; //avoid getAmountForMovePrice recalculation
                    break;
                }
            }

            uint amount = listAgg(LIMIT_SELL, price);
            //take the order of price 'price'.
            (uint amountInForTake, uint amountOutWithFee, uint communityFee,
                address[] memory accounts, uint[] memory amounts) =
                    _getAmountAndTake(LIMIT_BUY, amountAmmLeft, price, amount);
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
            _singleTransfer(IConfig(config).WETH(), baseToken, to, amountOrderBookOut);
        }

        // swap to target price when there is no limit order less than the target price
        if ((reserves[0] > 0 && reserves[1] > 0) && amountLeft > 0 && price != targetPrice) {
            (amountLeft, amountAmmBase, amountAmmQuote, reserves[2], reserves[3]) =
                OrderBookLibrary.getAmountForMovePrice(LIMIT_BUY, amountLeft,
                    reserves[0], reserves[1], targetPrice, decimal);
        }

        if (amountAmmQuote > 0) {
            if (amountLeft > 0) {
                (amountLeft, amountAmmQuote,) =
                    OrderBookLibrary.getFixAmountForMovePriceUp(amountLeft, amountAmmQuote, reserves[2], reserves[3],
                        targetPrice, decimal);
            }

            _ammSwapPrice(to, quoteToken, baseToken, amountAmmQuote, amountAmmBase);
            require(amountLeft == 0 || getPrice() >= targetPrice, "buy to target price failed");
        }
    }

    /*
        swap to price1 and take the order with price of price1 and
        swap to price2 and take the order with price of price2
        ......
        until all offered amount of limit order is consumed or price == target.
    */
    function _movePriceDown(uint amountOffer, uint targetPrice, address to) internal returns (uint amountLeft) {
        uint[] memory reserves = new uint[](4);//[reserveBase, reserveQuote, reserveBaseTmp, reserveQuoteTmp]
        (reserves[0], reserves[1]) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);
        (reserves[2], reserves[3]) = (reserves[0], reserves[1]);
        uint decimal = baseDecimal();
        amountLeft = amountOffer;
        uint amountAmmBase;
        uint amountAmmQuote;
        uint amountOrderBookOut;

        uint price = nextPrice(LIMIT_BUY, 0);
        while (price != 0 && price >= targetPrice) {
            uint amountAmmLeft = amountLeft;
            //skip if there is no liquidity in lp pool
            if (reserves[0] > 0 && reserves[1] > 0) {
                (amountAmmLeft, amountAmmBase, amountAmmQuote, reserves[2], reserves[3]) =
                OrderBookLibrary.getAmountForMovePrice(LIMIT_SELL, amountLeft,
                reserves[0], reserves[1], price, decimal);
                if (amountAmmLeft == 0) {
                    amountLeft = 0;  //avoid getAmountForMovePrice recalculation
                    break;
                }
            }

            uint amount = listAgg(LIMIT_BUY, price);
            //take the order of price 'price'.
            (uint amountInForTake, uint amountOutWithFee, uint communityFee,
                address[] memory accounts, uint[] memory amounts) =
                    _getAmountAndTake(LIMIT_SELL, amountAmmLeft, price, amount);
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
            _singleTransfer(IConfig(config).WETH(), quoteToken, to, amountOrderBookOut);
        }

        // swap to target price when there is no limit order less than the target price
        if ((reserves[0] > 0 && reserves[1] > 0) && amountLeft > 0 && price != targetPrice) {
            (amountLeft, amountAmmBase, amountAmmQuote, reserves[2], reserves[3]) =
                OrderBookLibrary.getAmountForMovePrice(LIMIT_SELL, amountLeft,
                    reserves[0], reserves[1], targetPrice, decimal);
        }

        if (amountAmmBase > 0) {
            if (amountLeft > 0) {
                (amountLeft, amountAmmBase,) =
                    OrderBookLibrary.getFixAmountForMovePriceDown(amountLeft, amountAmmBase, reserves[2], reserves[3],
                        targetPrice, decimal);
            }

            _ammSwapPrice(to, baseToken, quoteToken, amountAmmBase, amountAmmQuote);
            require(amountLeft == 0 || getPrice() <= targetPrice, "sell to target price failed");
        }
    }

    //limit order for buy base token with quote token
    function createBuyLimitOrder(address user, uint price, address to) external override lock returns (uint orderId) {
        require(price > 0 && (price % priceStep(price)) == 0, 'Price Invalid');
        IConfig(config).getOrderBookFactory();

        //get input amount of quote token for buy limit order
        uint balance = _getQuoteBalance();
        uint amountOffer = balance > quoteBalance ? balance - quoteBalance : 0;

        IPair(pair).skim(user);
        uint amountRemain = _movePriceUp(amountOffer, price, to);
        if (amountRemain != 0) {
            orderId = _addLimitOrder(to, amountOffer, amountRemain, price, LIMIT_BUY);
        }

        _updateBalance();
    }

    //limit order for sell base token to quote token
    function createSellLimitOrder(address user, uint price, address to) external override lock returns (uint orderId) {
        require(price > 0 && (price % priceStep(price)) == 0, 'Price Invalid');
        IConfig(config).getOrderBookFactory();

        //get input amount of base token for sell limit order
        uint balance = _getBaseBalance();
        uint amountOffer = balance > baseBalance ? balance - baseBalance : 0;

        IPair(pair).skim(user);
        uint amountRemain = _movePriceDown(amountOffer, price, to);
        if (amountRemain != 0) {
            orderId = _addLimitOrder(to, amountOffer, amountRemain, price, LIMIT_SELL);
        }

        _updateBalance();
    }

    //user send it's order to orderbook，then orderbook burn the order and refund
    function _cancelLimitOrder(address to, uint orderId) private lock {
        IOrderNFT.OrderDetail memory o = IOrderNFT(orderNFT).get(orderId);

        _removeLimitOrder(orderId, o);

        //refund
        address token = o._type == LIMIT_BUY ? quoteToken : baseToken;
        _singleTransfer(IConfig(config).WETH(), token, to, o._remain);

        //update token balance
        uint balance = IERC20(token).balanceOf(address(this));
        if (o._type == LIMIT_BUY) quoteBalance = balance;
        else baseBalance = balance;
    }

    /*******************************************************************************************************
                                    called by pair and router
     *******************************************************************************************************/
    function getAmountOutForMovePrice(address tokenIn, uint amountInOffer) external override view
    returns (uint amountOutGet, uint nextReserveBase, uint nextReserveQuote) {
        uint[] memory params = new uint[](7);
        (params[0], params[1]) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken); //reserveBase - reserveQuote
        (params[2], params[3]) = _getFeeRate(); //protocolFeeRate - subsidyFeeRate
        (params[4], params[5]) = getDirection(tokenIn);//tradeDir - orderDir
        params[6] = baseDecimal();
        uint amountInLeft = amountInOffer;
        amountOutGet = 0;
        (uint price, uint amount) = nextBook(params[5], 0);
        while (price != 0) {
            uint amountAmmLeft;
            (amountAmmLeft,,, nextReserveBase, nextReserveQuote) =
                OrderBookLibrary.getAmountForMovePrice(params[4], amountInLeft, params[0], params[1], price, params[6]);
            if (amountAmmLeft == 0) {
                break;
            }

            (uint amountInForTake, uint amountOutWithFee, uint communityFee) = OrderBookLibrary.getAmountOutForTakePrice(
                params[4], amountAmmLeft, price, params[6], params[2], params[3], amount);
            amountOutGet += amountOutWithFee.sub(communityFee);
            amountInLeft = amountInLeft.sub(amountInForTake);
            if (amountInForTake == amountAmmLeft) {
                break;
            }

            (price, amount) = nextBook(params[5], price);
        }

        if (amountInLeft > 0) {
            amountOutGet += params[4] == LIMIT_BUY ?
                OrderBookLibrary.getAmountOut(amountInLeft, params[1], params[0]) :
                OrderBookLibrary.getAmountOut(amountInLeft, params[0], params[1]);
        }
    }

    function getAmountInForMovePrice(address tokenOut, uint amountOutOffer) external override view
    returns (uint amountInGet, uint nextReserveBase, uint nextReserveQuote) {
        uint[] memory params = new uint[](7);
        (params[0], params[1]) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken); //reserveBase - reserveQuote
        (params[2], params[3]) = _getFeeRate(); //protocolFeeRate - subsidyFeeRate
        (params[5], params[4]) = getDirection(tokenOut);//orderDir - tradeDir
        params[6] = baseDecimal();
        uint amountOutLeft = amountOutOffer;
        amountInGet = 0;
        (uint price, uint amount) = nextBook(params[5], 0);
        while (price != 0) {
            uint amountAmmLeft;
            (amountAmmLeft,,, nextReserveBase, nextReserveQuote) =
                OrderBookLibrary.getAmountForMovePriceWithAmountOut(params[4], amountOutLeft, params[0], params[1],
                    price, params[6]);
            if (amountAmmLeft == 0) {
                break;
            }

            //计算消耗掉一个价格的挂单需要的amountOut数量
            (uint amountInForTake, uint amountOutWithFee, uint communityFee) = OrderBookLibrary.getAmountInForTakePrice
                (params[4], amountAmmLeft, price, params[6], params[2], params[3], amount);
            amountInGet += amountInForTake.add(1);
            amountOutLeft = amountOutLeft.sub(amountOutWithFee.sub(communityFee));
            if (amountOutWithFee == amountAmmLeft) {
                break;
            }

            (price, amount) = nextBook(params[5], price);
        }

        if (amountOutLeft > 0) {
            amountInGet += params[4] == LIMIT_BUY ?
            OrderBookLibrary.getAmountIn(amountOutLeft, params[1], params[0]) :
            OrderBookLibrary.getAmountIn(amountOutLeft, params[0], params[1]);
        }
    }

    function takeOrderWhenMovePrice(address tokenIn, uint amountIn, address to) external override lock
    returns (uint amountOutLeft, address[] memory accounts, uint[] memory amounts) {
        //take order before pay, make sure only pair can call this function
        require(msg.sender == pair, 'invalid sender');
        uint[] memory reserves = new uint[](2);//[reserveBase, reserveQuote]
        (reserves[0], reserves[1]) = OrderBookLibrary.getReserves(pair, baseToken, quoteToken);

        //direction for tokenA swap to tokenB
        (uint tradeDir, uint orderDir) = getDirection(tokenIn);
        uint decimal = baseDecimal();
        (uint price, uint amount) = nextBook(orderDir, 0);
        while (price != 0) {
            (uint amountAmmLeft,,,,) =
                OrderBookLibrary.getAmountForMovePrice(
                    tradeDir,
                    amountIn,
                    reserves[0],
                    reserves[1],
                    price,
                    decimal);
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
