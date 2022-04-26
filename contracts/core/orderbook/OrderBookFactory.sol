// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import '../pair/interfaces/IPairFactory.sol';
import './OrderBook.sol';
import "./interfaces/IOrderBookFactory.sol";
import "./OrderNFT.sol";

contract OrderBookFactory is IOrderBookFactory {
    mapping(address => mapping(address => address)) public override getOrderBook;
    address[] public override allOrderBooks;
    address public override pairFactory;
    address public override WETH;
    address public config;

    event OrderBookCreated(address, address, address, address);

    constructor(address _pairFactory, address _WETH, address _config) {
        (pairFactory, WETH, config) = (_pairFactory, _WETH, _config);
    }

    function allOrderBookLength() external override view returns (uint) {
        return allOrderBooks.length;
    }

    //create order book
    function createOrderBook(address baseToken, address quoteToken) external override {
        require(baseToken != quoteToken, 'OF: IDENTICAL_ADDRESSES');
        (address token0, address token1) = baseToken < quoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        require(token0 != address(0), 'OF: ZERO_ADDRESS');
        require(getOrderBook[token0][token1] == address(0), 'OF: ORDER_BOOK_EXISTS');

        address pair = IPairFactory(pairFactory).getPair(token0, token1);
        require(pair != address(0), 'OF: TOKEN_PAIR_NOT_EXISTS');
        bytes memory bytecode = type(OrderBook).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        address orderBook;
        assembly {
            orderBook := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        OrderNFT orderNFT = new OrderNFT(orderBook);
        IOrderBook(orderBook).initialize(pair, baseToken, quoteToken, address(orderNFT));
        (getOrderBook[token0][token1], getOrderBook[token1][token0]) = (orderBook, orderBook);
        allOrderBooks.push(orderBook);
        emit OrderBookCreated(pair, baseToken, quoteToken, orderBook);
    }

    function getCodeHash() external pure override returns (bytes32) {
        return keccak256(type(OrderBook).creationCode);
    }
}
