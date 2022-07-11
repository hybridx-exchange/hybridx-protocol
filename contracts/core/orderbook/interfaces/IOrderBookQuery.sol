// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOrderBookQuery {

    //get amount out for move price, include swap and take, and call by uniswap v2 pair
    function getAmountOutForMovePrice(address orderBook, address tokenIn, uint amountInOffer) external view
        returns (uint amountOut, uint[] memory extra);

    //get amount in for move price, include swap and take, and call by uniswap v2 pair
    function getAmountInForMovePrice(address orderBook, address tokenOut, uint amountOutOffer) external view
        returns (uint amountIn, uint[] memory extra);
}
