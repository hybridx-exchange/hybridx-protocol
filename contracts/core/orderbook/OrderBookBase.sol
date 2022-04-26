// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../deps/interfaces/IERC20.sol";
import "../../deps/interfaces/IWETH.sol";
import "../../deps/libraries/UQ112x112.sol";
import '../../deps/libraries/TransferHelper.sol';
import "./libraries/OrderBookLibrary.sol";
import "./OrderQueue.sol";
import "./PriceList.sol";

contract OrderBookBase is OrderQueue, PriceList {
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
    mapping(uint => Order) public override marketOrders;

    //用户订单(用户地址 -> 订单id数组)
    mapping(address => uint[]) public override userOrders;

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(
        address _pair,
        address _baseToken,
        address _quoteToken,
        address _orderNFT)
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

    //更新协议费率，开放修改需要考虑抢先交易问题，暂时由社区账号管理
    function protocolFeeRateUpdate(uint newProtocolFeeRate) external override lock {
        require(msg.sender == OrderBookLibrary.getAdmin(factory),
            "Forbidden");
        require(newProtocolFeeRate <= 30, "Invalid Fee Rate"); //max fee is 0.3%, default is 0.1%
        protocolFeeRate = newProtocolFeeRate;
    }

    //更新gas补贴费率
    function subsidyFeeRateUpdate(uint newSubsidyFeeRate) external override lock {
        require(msg.sender == OrderBookLibrary.getAdmin(factory), "Forbidden");
        require(newSubsidyFeeRate <= 100, "Invalid Fee Rate"); //max is 100% of protocolFeeRate
        subsidyFeeRate = newSubsidyFeeRate;
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
}
