// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../config/interfaces/IConfig.sol";
import "../pair/interfaces/IPairFactory.sol";
import "./interfaces/IOrder.sol";
import "./interfaces/IOrderBook.sol";
import "./interfaces/IOrderBookFactory.sol";
import "../deps/access/Ownable.sol";

contract OrderBookFactory is IOrderBookFactory {
    mapping(address => mapping(address => address)) public override getOrderNFT;
    mapping(address => mapping(address => address)) public override getOrderBook;
    address[] public override allOrderNFTs;
    address[] public override allOrderBooks;
    address public override pairFactory;
    address public override WETH;
    address public override config;

    event OrderBookCreated(address, address, address, address);
    event OrderNFTCreated(address, address, address, address);

    constructor(address _pairFactory, address _WETH, address _config) {
        (pairFactory, WETH, config) = (_pairFactory, _WETH, _config);
    }

    function allOrderBookLength() external override view returns (uint) {
        return allOrderBooks.length;
    }

    function allOrderNFTLength() external override view returns (uint) {
        return allOrderNFTs.length;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a without making any external calls
    function orderBookFor(address tokenA, address tokenB) internal view returns (address orderBook) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        orderBook = address(uint160(bytes20(keccak256(abi.encodePacked(
            hex'ff',
            address(this),
            keccak256(abi.encodePacked(token0, token1)),
            this.getOrderBookCodeHash() // init code hash
        )))));
    }

    //create order NFT
    function createOrderNFT(address baseToken, address quoteToken) external override {
        require(baseToken != quoteToken, 'OF: IDENTICAL_ADDRESSES');
        (address token0, address token1) = sortTokens(baseToken, quoteToken);
        require(token0 != address(0), 'OF: ZERO_ADDRESS');
        require(getOrderNFT[token0][token1] == address(0), 'OF: ORDER_NFT_EXISTS');
        address orderBook = orderBookFor(baseToken, quoteToken);

        bytes memory bytecode = IConfig(config).orderNFTByteCode();
        require(bytecode.length != 0, 'OF: NO_ORDER_NFT_BYTE_CODE');

        bytes32 salt = keccak256(abi.encodePacked(orderBook, token0, token1));
        address orderNFT;
        assembly {
            orderNFT := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IOrder(orderNFT).initialize(Ownable(config).owner(), orderBook);
        (getOrderNFT[token0][token1], getOrderNFT[token1][token0]) = (orderNFT, orderNFT);
        allOrderNFTs.push(orderNFT);
        emit OrderNFTCreated(orderBook, baseToken, quoteToken, orderNFT);
    }

    //create order book
    function createOrderBook(address baseToken, address quoteToken) external override {
        require(baseToken != quoteToken, 'OF: IDENTICAL_ADDRESSES');
        (address token0, address token1) = sortTokens(baseToken, quoteToken);
        require(token0 != address(0), 'OF: ZERO_ADDRESS');
        require(getOrderBook[token0][token1] == address(0), 'OF: ORDER_BOOK_EXISTS');
        require(getOrderNFT[token0][token1] != address(0), 'OF: ORDER_NFT_NOT_EXISTS');

        address pair = IPairFactory(pairFactory).getPair(token0, token1);
        require(pair != address(0), 'OF: TOKEN_PAIR_NOT_EXISTS');
        bytes memory bytecode = IConfig(config).orderBookByteCode();
        require(bytecode.length != 0, 'OF: NO_ORDER_BOOK_BYTE_CODE');
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        address orderBook;
        assembly {
            orderBook := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IOrderBook(orderBook).initialize(pair, baseToken, quoteToken, getOrderNFT[token0][token1], config);
        (getOrderBook[token0][token1], getOrderBook[token1][token0]) = (orderBook, orderBook);
        allOrderBooks.push(orderBook);
        emit OrderBookCreated(pair, baseToken, quoteToken, orderBook);
    }

    function getOrderNFTCodeHash() external view override returns (bytes32) {
        return keccak256(IConfig(config).orderNFTByteCode());
    }

    function getOrderBookCodeHash() external view override returns (bytes32) {
        return keccak256(IConfig(config).orderBookByteCode());
    }
}
