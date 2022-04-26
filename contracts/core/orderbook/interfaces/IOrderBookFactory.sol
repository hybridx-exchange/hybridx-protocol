// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOrderBookFactory {
    function WETH() external view returns (address);
    function pairFactory() external view returns (address);
    function getOrderBook(address tokenA, address tokenB) external view returns (address orderBook);
    function allOrderBooks(uint) external view returns (address orderBook);
    function allOrderBookLength() external view returns (uint length);
    function createOrderBook(address baseToken, address quoteToken) external;
    function getCodeHash() external pure returns (bytes32);
}