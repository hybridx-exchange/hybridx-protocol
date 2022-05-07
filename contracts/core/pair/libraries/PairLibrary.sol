// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../../deps/libraries/SafeMath.sol";
import '../../../config/interfaces/IConfig.sol';
import '../../orderbook/interfaces/IOrderBook.sol';
import '../../orderbook/interfaces/IOrderBookFactory.sol';
import "../interfaces/IPair.sol";
import "../interfaces/IPairFactory.sol";

library PairLibrary {
    using SafeMath for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');
    }

    function getPair(address factory, address tokenA, address tokenB) internal view returns (address pair) {
        pair = IPairFactory(factory).getPair(tokenA, tokenB);
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view
    returns (uint reserveA, uint reserveB, address pair) {
        (address token0,) = sortTokens(tokenA, tokenB);
        pair = IPairFactory(factory).getPair(tokenA, tokenB);
        if (pair != address(0)) {
            (uint reserve0, uint reserve1,) = IPair(pair).getReserves();
            (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        }
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    function getOrderBook(address config, address tokenA, address tokenB) internal view returns (address orderBook) {
        address orderBookFactory = IConfig(config).getOrderBookFactory();
        if (orderBookFactory != address(0)){
            return IOrderBookFactory(orderBookFactory).getOrderBook(tokenA, tokenB);
        }
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view
    returns (uint[] memory amounts) {
        require(path.length >= 2, 'INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        address config = IPairFactory(factory).config();
        for (uint i; i < path.length - 1; i++) {
            address orderBook = getOrderBook(config, path[i], path[i + 1]);
            if (orderBook != address(0)) {
                (amounts[i + 1],) = IOrderBook(orderBook).getAmountOutForMovePrice(path[i], amounts[i]);
            }
            else {
                (uint reserveIn, uint reserveOut,) = getReserves(factory, path[i], path[i + 1]);
                amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
            }
        }
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getSpecificAmountOut(address orderBook, address tokenIn, uint amountIn, uint reserveIn, uint reserveOut)
    internal view returns (uint amountOut) {
        if (orderBook != address(0)) {
            (amountOut,) = IOrderBook(orderBook).getAmountOutForMovePrice(tokenIn, amountIn);
        }
        else {
            amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        }
    }

    function getAmountOutWithExtra(address factory, address tokenIn, address tokenOut, uint amountIn, uint indexStart)
    internal view returns (uint amountOut, uint[] memory extraOut) {
        (uint reserveIn, uint reserveOut,) = getReserves(factory, tokenIn, tokenOut);
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        (
            extraOut[indexStart],
            extraOut[indexStart + 1],
            extraOut[indexStart + 2],
            extraOut[indexStart + 3]
        ) = (reserveIn + amountIn, reserveOut - amountOut, amountIn, amountOut);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOutWithNextReserves(address factory, uint amountIn, address[] memory path) internal view
    returns (uint[] memory amounts, uint[] memory nextReserves) {
        require(path.length >= 2, 'INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        nextReserves = new uint[](6 * (path.length - 1));
        address config = IPairFactory(factory).config();
        for (uint i; i < path.length - 1; i++) {
            uint index = 6 * i;
            address orderBook = getOrderBook(config, path[i], path[i + 1]);
            if (orderBook != address(0)) {
                uint[] memory extra;
                (amounts[i + 1], extra) = IOrderBook(orderBook).getAmountOutForMovePrice(path[i], amounts[i]);
                (nextReserves[index], nextReserves[index + 1]) = IOrderBook(orderBook).baseToken() == path[i] ?
                    (extra[0], extra[1]) : (extra[1], extra[0]);
                (nextReserves[index + 2], nextReserves[index + 3], nextReserves[index + 4], nextReserves[index + 5]) =
                    (extra[2], extra[3], extra[4], extra[5]);
            }
            else {
                (amounts[i + 1], nextReserves) =
                    getAmountOutWithExtra(factory, path[i], path[i + 1], amounts[i], 6 * i);
            }
        }
    }

    function getBestAmountsOut(address factory, uint amountIn, address[][] memory paths) internal view
    returns (address[] memory path, uint[] memory amounts, uint[] memory nextReserves) {
        require(paths.length >= 1, 'INVALID_PATHS');
        uint index = paths.length;
        uint maxAmountOut;
        for (uint i; i<paths.length; i++) {
            (uint[] memory amountsTmp, uint[] memory nextReservesTmp) =
                getAmountsOutWithNextReserves(factory, amountIn, paths[i]);
            if (maxAmountOut < amountsTmp[amountsTmp.length-1]) {
                (index, maxAmountOut, amounts, nextReserves) =
                    (i, amountsTmp[amountsTmp.length-1], amountsTmp, nextReservesTmp);
            }
        }

        assert(index != paths.length);
        path = paths[index];
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view
    returns (uint[] memory amounts) {
        require(path.length >= 2, 'INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        address config = IPairFactory(factory).config();
        for (uint i = path.length - 1; i > 0; i--) {
            address orderBook = getOrderBook(config, path[i - 1], path[i]);
            if (orderBook != address(0)) {
                (amounts[i - 1],) = IOrderBook(orderBook).getAmountInForMovePrice(path[i], amounts[i]);
            }
            else {
                (uint reserveIn, uint reserveOut,) = getReserves(factory, path[i - 1], path[i]);
                amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
            }
        }
    }

    function getAmountInWithExtra(address factory, address tokenIn, address tokenOut, uint amountOut, uint indexStart)
    internal view returns (uint amountIn, uint[] memory extraOut) {
        (uint reserveIn, uint reserveOut,) = getReserves(factory, tokenIn, tokenOut);
        amountIn = getAmountIn(amountOut, reserveIn, reserveOut);
        (
            extraOut[indexStart],
            extraOut[indexStart + 1],
            extraOut[indexStart + 2],
            extraOut[indexStart + 3]
        ) = (reserveIn + amountIn, reserveOut - amountOut, amountIn, amountOut);
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsInWithNextReserves(address factory, uint amountOut, address[] memory path) internal view
    returns (uint[] memory amounts, uint[] memory nextReserves) {
        require(path.length >= 2, 'INVALID_PATH');
        amounts = new uint[](path.length);
        nextReserves = new uint[](6 * (path.length - 1));
        amounts[amounts.length - 1] = amountOut;
        address config = IPairFactory(factory).config();
        for (uint i = path.length - 1; i > 0; i--) {
            address orderBook = getOrderBook(config, path[i - 1], path[i]);
            if (orderBook != address(0)) {
                uint[] memory extra;
                uint index = 6 * (i - 1);
                (amounts[i - 1], extra) = IOrderBook(orderBook).getAmountInForMovePrice(path[i], amounts[i]);
                (nextReserves[index], nextReserves[index + 1]) = IOrderBook(orderBook).baseToken() == path[i - 1] ?
                    (extra[0], extra[1]) : (extra[1], extra[2]);
                (nextReserves[index + 2], nextReserves[index + 3], nextReserves[index + 4], nextReserves[index + 5]) =
                    (extra[2], extra[2], extra[4], extra[5]);
            }
            else {
                (amounts[i - 1], nextReserves) =
                    getAmountInWithExtra(factory, path[i - 1], path[i], amounts[i], 6 * (i - 1));
            }
        }
    }

    function getBestAmountsIn(address factory, uint amountOut, address[][] memory paths) internal view
    returns (address[] memory path, uint[] memory amounts, uint[] memory nextReserves) {
        require(paths.length >= 1, 'INVALID_PATHS');
        uint index;
        uint minAmountIn = type(uint).max;
        for (uint i; i<paths.length; i++){
            (uint[] memory amountsTmp, uint[] memory nextReservesTmp) =
                getAmountsInWithNextReserves(factory, amountOut, paths[i]);
            if (minAmountIn > amountsTmp[0]) {
                (index, minAmountIn, amounts, nextReserves) = (i, amountsTmp[0], amountsTmp, nextReservesTmp);
            }
        }

        assert(index != paths.length);
        path = paths[index];
    }
}