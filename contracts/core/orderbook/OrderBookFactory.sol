// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../config/interfaces/IConfig.sol";
import "../pair/interfaces/IPairFactory.sol";
import "./interfaces/IOrder.sol";
import "./interfaces/IOrderBookQuery.sol";
import "./interfaces/IOrderBook.sol";
import "./interfaces/IOrderBookFactory.sol";
import "../../deps/access/Ownable.sol";
/**************************************************************************************************************
@title                          factory for hybrid order book
@author                         https://twitter.com/cherideal
@ens                            cherideal.eth
**************************************************************************************************************/
contract OrderBookFactory is IOrderBookFactory {
    mapping(address => mapping(address => address)) public override getOrderNFT;
    mapping(address => mapping(address => address)) public override getOrderBook;
    mapping(address => mapping(address => address)) public override getOrderBookQuery;
    address[] public override allOrderNFTs;
    address[] public override allOrderBooks;
    address[] public override allOrderBookQueries;
    address public override config;

    event OrderBookCreated(address, address, address, address);
    event OrderNFTCreated(address, address, address, address);
    event OrderUtilCreated(address, address, address, address);

    constructor(address _config) {
        config = _config;
    }

    function allOrderBookLength() external override view returns (uint) {
        return allOrderBooks.length;
    }

    function allOrderNFTLength() external override view returns (uint) {
        return allOrderNFTs.length;
    }

    function allOrderBookQueryLength() external override view returns (uint) {
        return allOrderBookQueries.length;
    }

    //create order book
    function createOrderBook(address baseToken, address quoteToken) external override returns (address orderBook){
        require(baseToken != quoteToken, 'OrderBookFactory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = baseToken < quoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        require(token0 != address(0), 'OrderBookFactory: ZERO_ADDRESS');
        require(getOrderBook[token0][token1] == address(0), 'OrderBookFactory: ORDER_BOOK_EXISTS');

        bytes memory orderBookByteCode = IConfig(config).getOrderBookByteCode();
        require(orderBookByteCode.length != 0, 'OrderBookFactory: NO_ORDER_BOOK_BYTE_CODE');

        bytes memory orderNFTByteCode = IConfig(config).getOrderNFTByteCode();
        require(orderNFTByteCode.length != 0, 'OrderBookFactory: NO_ORDER_NFT_BYTE_CODE');

        address pair = IPairFactory(IConfig(config).getPairFactory()).getPair(token0, token1);
        require(pair != address(0), 'OrderBookFactory: TOKEN_PAIR_NOT_EXISTS');

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            orderBook := create2(0, add(orderBookByteCode, 32), mload(orderBookByteCode), salt)
        }
        require(orderBook != address(0), 'OrderBookFactory: CREATE_ORDER_BOOK_FAILED');

        salt = keccak256(abi.encodePacked(orderBook, token0, token1));
        address orderNFT;
        assembly {
            orderNFT := create2(0, add(orderNFTByteCode, 32), mload(orderNFTByteCode), salt)
        }
        require(orderNFT != address(0), 'OrderBookFactory: CREATE_ORDER_NFT_FAILED');

        IOrder(orderNFT).initialize(allOrderNFTs.length, Ownable(config).owner(), orderBook);
        (getOrderNFT[token0][token1], getOrderNFT[token1][token0]) = (orderNFT, orderNFT);
        allOrderNFTs.push(orderNFT);
        emit OrderNFTCreated(orderBook, baseToken, quoteToken, orderNFT);

        IOrderBook(orderBook).initialize(pair, baseToken, quoteToken, orderNFT, config);
        (getOrderBook[token0][token1], getOrderBook[token1][token0]) = (orderBook, orderBook);
        allOrderBooks.push(orderBook);
        emit OrderBookCreated(pair, baseToken, quoteToken, orderBook);
    }

    function getOrderNFTCodeHash() external view override returns (bytes32) {
        return keccak256(IConfig(config).getOrderNFTByteCode());
    }

    function getOrderBookCodeHash() external view override returns (bytes32) {
        return keccak256(IConfig(config).getOrderBookByteCode());
    }
}
