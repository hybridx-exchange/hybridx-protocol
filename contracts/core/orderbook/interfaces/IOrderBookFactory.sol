// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOrderBookFactory {
    function WETH() external view returns (address);
    function pairFactory() external view returns (address);
    function config() external view returns (address);
    function getOrderNFT(address tokenA, address tokenB) external view returns (address orderNFT);
    function getOrderBook(address tokenA, address tokenB) external view returns (address orderBook);
    function allOrderBooks(uint) external view returns (address orderBook);
    function allOrderBookLength() external view returns (uint length);
    function createOrderNFT(address baseToken, address quoteToken) external;
    function createOrderBook(address baseToken, address quoteToken) external;
    function getOrderNFTCodeHash() external view returns (bytes32);
    function getOrderBookCodeHash() external view returns (bytes32);
}