// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOrderBook {
    //order book contract init function
    function initialize(address _pair, address _baseToken, address _quoteToken, address _orderNFT, address _config) external;

    function reverse() external;

    //create limit buy order
    function createBuyLimitOrder(address user, uint price, address to) external returns (uint orderId);

    //create limit sell order
    function createSellLimitOrder(address user, uint price, address to) external returns (uint orderId);

    //return market order book information([price...], [amount...])
    function marketBook(uint direction, uint32 maxSize) external view returns (uint[] memory prices, uint[] memory amounts);

    //order book within price range
    function rangeBook(uint direction, uint price) external view returns (uint[] memory prices, uint[] memory amounts);

    //get lp price
    function getPrice() external view returns (uint price);

    function getReserves() external view returns (uint112 reserveBase, uint112 reserveQuote);

    //get pair address
    function pair() external view returns (address);

    //get order book factory address
    function orderBookFactory() external view returns (address);

    //get config address
    function config() external view returns (address);

    //get order nft address
    function orderNFT() external view returns (address);

    //get base token balance record
    function baseBalance() external view returns (uint);
    //get base token balance record
    function quoteBalance() external view returns (uint);

    //get base token decimal
    function baseDecimal() external view returns (uint);
    //get price decimal
    function priceDecimal() external view returns (uint);
    //get price step
    function priceStep(uint price) external view returns (uint);

    //base token -- eg: btc
    function baseToken() external view returns (address);
    //quote token -- eg: usdc
    function quoteToken() external view returns (address);

    function safeRefund(address token, address payable to) external;
    //get amount out for move price, include swap and take, and call by uniswap v2 pair
    function getAmountOutForMovePrice(address tokenIn, uint amountInOffer) external view
        returns (uint amountOut, uint nextReserveBase, uint nextReserveQuote, uint[] memory extra);

    //get amount in for move price, include swap and take, and call by uniswap v2 pair
    function getAmountInForMovePrice(address tokenOut, uint amountOutOffer) external view
        returns (uint amountIn, uint nextReserveBase, uint nextReserveQuote, uint[] memory extra);

    //take order when move price by uniswap v2 pair
    function takeOrderWhenMovePrice(address tokenIn, uint amountIn, address to) external
        returns (uint amountOut, address[] memory accounts, uint[] memory amounts);

    function cancelLimitOrder(address to, uint orderId) external;
}
