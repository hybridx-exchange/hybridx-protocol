// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../core/orderbook/libraries/OrderBookLibrary.sol";
import "../../deps/interfaces/IWETH.sol";
import '../../deps/libraries/TransferHelper.sol';
import "./interfaces/IOrderBookRouter.sol";

/**************************************************************************************************************
@title                          router for hybrid order book
@author                         https://twitter.com/cherideal
@ens                            cherideal.eth
**************************************************************************************************************/
contract OrderBookRouter is IOrderBookRouter {
    address public override config;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'HybridRouter: EXPIRED');
        _;
    }

    constructor(address _config) {
        config = _config;
    }

    /**************************************************************************************************************
    @param amountOffer             amount offered for limit order
    @param price                   price of limit order
    @param baseToken               base token of order book
    @param quoteToken              quote token of order book
    @param to                      account for received token when the order is filled
    @param deadline                dead line for this transaction
    @return orderId                order id when order is placed
    **************************************************************************************************************/
    function buyWithToken(
        uint amountOffer,
        uint price,
        address baseToken,
        address quoteToken,
        address to,
        uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint orderId) {
        require(baseToken != quoteToken, 'HybridRouter: Invalid_Path');
        address orderBookFactory = IConfig(config).getOrderBookFactory();
        address orderBook = IOrderBookFactory(orderBookFactory).getOrderBook(baseToken, quoteToken);
        if (orderBook == address(0)) {
            orderBook = IOrderBookFactory(orderBookFactory).createOrderBook(baseToken, quoteToken);
        }

        require(quoteToken == IOrderBook(orderBook).quoteToken(), "HybridRouter: MisOrder_Path");
        TransferHelper.safeTransferFrom(
            quoteToken, msg.sender, orderBook, amountOffer
        );

        to = to == address(0) ? msg.sender : to;
        orderId = IOrderBook(orderBook).createBuyLimitOrder(msg.sender, price, to);
    }

    //buy base token with eth (eth -> uni)
    function buyWithEth(
        uint price,
        address baseToken,
        address to,
        uint deadline)
        external
        virtual
        payable
        override
        ensure(deadline)
        returns (uint orderId)
    {
        address WETH = IConfig(config).WETH();
        require(baseToken != WETH, 'HybridRouter: Invalid_Path');
        address orderBookFactory = IConfig(config).getOrderBookFactory();
        address orderBook = IOrderBookFactory(orderBookFactory).getOrderBook(baseToken, WETH);
        if (orderBook == address(0)) {
            orderBook = IOrderBookFactory(orderBookFactory).createOrderBook(baseToken, WETH);
        }

        require(IOrderBook(orderBook).quoteToken() == WETH, 'HybirdRouter: MisOrder_Path');
        IWETH(WETH).deposit{value: msg.value}();
        assert(IWETH(WETH).transfer(orderBook, msg.value));

        to = to == address(0) ? msg.sender : to;
        orderId = IOrderBook(orderBook).createBuyLimitOrder(msg.sender, price, to);
    }

    //sell base token to quote token (uni -> usdc)
    function sellToken(
        uint amountOffer,
        uint price,
        address baseToken,
        address quoteToken,
        address to,
        uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint orderId)
    {
        require(baseToken != quoteToken, 'HybridRouter: Invalid_Path');
        address orderBookFactory = IConfig(config).getOrderBookFactory();
        address orderBook = IOrderBookFactory(orderBookFactory).getOrderBook(baseToken, quoteToken);
        if (orderBook == address(0)) {
            orderBook = IOrderBookFactory(orderBookFactory).createOrderBook(baseToken, quoteToken);
        }

        require(quoteToken == IOrderBook(orderBook).quoteToken(), "HybridRouter: MisOrder_Path");
        TransferHelper.safeTransferFrom(
            baseToken, msg.sender, orderBook, amountOffer
        );

        to = to == address(0) ? msg.sender : to;
        orderId = IOrderBook(orderBook).createSellLimitOrder(msg.sender, price, to);
    }

    //sell eth to quote token (eth -> usdc)
    function sellEth(
        uint price,
        address quoteToken,
        address to,
        uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint orderId)
    {
        address WETH = IConfig(config).WETH();
        require(WETH != quoteToken, 'HybridRouter: Invalid_Path');
        address orderBookFactory = IConfig(config).getOrderBookFactory();
        address orderBook = IOrderBookFactory(orderBookFactory).getOrderBook(WETH, quoteToken);
        if (orderBook == address(0)) {
            orderBook = IOrderBookFactory(orderBookFactory).createOrderBook(WETH, quoteToken);
        }

        require(WETH == IOrderBook(orderBook).baseToken(), 'HybridRouter: MisOrder_Path');
        IWETH(WETH).deposit{value: msg.value}();
        assert(IWETH(WETH).transfer(orderBook, msg.value));

        to = to == address(0) ? msg.sender : to;
        orderId = IOrderBook(orderBook).createSellLimitOrder(msg.sender, price, to);
    }

    /**************************************************************************************************************
    @param amountOffer             amount offered for limit order
    @param price                   price of limit order
    @param tokenA                  one token of order book
    @param tokenB                  another token of order book
    @return amounts                [amm amount in, amm amount out, order amount in, order amount out,
                                    order fee, amount left, price to]
    **************************************************************************************************************/
    function getAmountsForBuy(uint amountOffer, uint price, address tokenA, address tokenB)
    external
    virtual
    override
    view
    returns (uint[] memory amounts) { //ammAmountIn, ammAmountOut, orderAmountIn, orderAmountOut, fee
        require(tokenA != tokenB, 'HybridRouter: Invalid_Path');
        address orderBook = IOrderBookFactory(IConfig(config).getOrderBookFactory()).getOrderBook(tokenA, tokenB);
        if (orderBook != address(0)) {
            (address baseToken, address quoteToken) = IOrderBook(orderBook).baseToken() == tokenA ?
                (tokenA, tokenB) : (tokenB, tokenA);
            (uint reserveBase, uint reserveQuote) = OrderBookLibrary.getReserves(
                IOrderBook(orderBook).pair(),
                baseToken,
                quoteToken);
            amounts = OrderBookLibrary.getAmountsForBuyLimitOrder(orderBook, amountOffer, price, reserveBase, reserveQuote);
        }
    }

    function getAmountsForSell(uint amountOffer, uint price, address tokenA, address tokenB)
    external
    virtual
    override
    view
    returns (uint[] memory amounts) { //ammAmountIn, ammAmountOut, orderAmountIn, orderAmountOut
        require(tokenA != tokenB, 'HybridRouter: Invalid_Path');
        address orderBook = IOrderBookFactory(IConfig(config).getOrderBookFactory()).getOrderBook(tokenA, tokenB);
        if (orderBook != address(0)) {
            (address baseToken, address quoteToken) = IOrderBook(orderBook).baseToken() == tokenA ?
                (tokenA, tokenB) : (tokenB, tokenA);
                (uint reserveBase, uint reserveQuote) = OrderBookLibrary.getReserves(
                IOrderBook(orderBook).pair(),
                baseToken,
                quoteToken);
            amounts = OrderBookLibrary.getAmountsForSellLimitOrder(orderBook, amountOffer, price, reserveBase, reserveQuote);
        }
    }

    //get order book information
    function getOrderBook(address tokenA, address tokenB, uint32 limitSize)
    external
    virtual
    override
    view
    returns
    (uint price, uint[] memory buyPrices, uint[] memory buyAmounts, uint[] memory sellPrices, uint[] memory sellAmounts)
    {
        require(tokenA != tokenB, 'HybridRouter: Invalid_Path');
        address orderBook = IOrderBookFactory(IConfig(config).getOrderBookFactory()).getOrderBook(tokenA, tokenB);
        if (orderBook != address(0)) {
            price = IOrderBook(orderBook).getPrice();
            (buyPrices, buyAmounts) = IOrderBook(orderBook).marketBook(OrderBookLibrary.LIMIT_BUY, limitSize);
            (sellPrices, sellAmounts) = IOrderBook(orderBook).marketBook(OrderBookLibrary.LIMIT_SELL, limitSize);
        }
    }
}
