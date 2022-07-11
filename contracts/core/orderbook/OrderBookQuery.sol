// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IOrderBook.sol";
import "./libraries/OrderBookLibrary.sol";
import "./interfaces/IOrderBookQuery.sol";
import { LIMIT_BUY, LIMIT_SELL } from "../../deps/libraries/Const.sol";

contract OrderBookQuery is IOrderBookQuery {
    using SafeMath for uint;

    /*******************************************************************************************************
                                    called by pair router
    *******************************************************************************************************/
    function getAmountOutForMovePrice(address orderBook, address tokenIn, uint amountInOffer) external override view
    returns (uint amountOutGet, uint[] memory extra) {
        uint[] memory params = new uint[](7);
        address[] memory addresses = new address[](3);
        extra = new uint[](6); //nextReserveIn, nextReserveOut, ammIn, ammOut, orderIn, orderOutWithSubsidyFee
        //baseToken, quoteToken
        (addresses[0], addresses[1], addresses[2]) =
            (IOrderBook(orderBook).pair(), IOrderBook(orderBook).baseToken(), IOrderBook(orderBook).quoteToken());
        //reserveBase - reserveQuote
        (params[0], params[1]) = OrderBookLibrary.getReserves(addresses[0], addresses[1], addresses[2]);
        (params[2], params[3]) = IOrderBook(orderBook).getFeeRate(); //protocolFeeRate - subsidyFeeRate
        (params[4], params[5]) = OrderBookLibrary.getDirection(addresses[2], tokenIn);//tradeDir - orderDir
        params[6] = IOrderBook(orderBook).baseDecimal();
        uint amountInLeft = amountInOffer;
        amountOutGet = 0;
        (uint price, uint amount) = IOrderBook(orderBook).nextBook(params[5], 0);
        while (price != 0) {
            uint amountAmmLeft;
            if (params[4] == LIMIT_BUY) {
                (amountAmmLeft, extra[1], extra[0], extra[3], extra[2]) =
                OrderBookLibrary.getAmountForMovePrice(params[4], amountInLeft, params[0], params[1],
                    price, params[6]);
            }
            else {
                (amountAmmLeft, extra[0], extra[1], extra[2], extra[3]) =
                OrderBookLibrary.getAmountForMovePrice(params[4], amountInLeft, params[0], params[1],
                    price, params[6]);
            }

            if (amountAmmLeft == 0) {
                break;
            }

            (uint amountInForTake, uint amountOutWithFee, uint communityFee) = OrderBookLibrary.getAmountOutForTakePrice
            (params[4], amountAmmLeft, price, params[6], params[2], params[3], amount);
            extra[4] += amountInForTake;
            extra[5] += amountOutWithFee.sub(communityFee);
            amountOutGet += amountOutWithFee.sub(communityFee);
            amountInLeft = amountInLeft.sub(amountInForTake);
            if (amountInForTake == amountAmmLeft) {
                break;
            }

            (price, amount) = IOrderBook(orderBook).nextBook(params[5], price);
        }

        if (amountInLeft > 0) {
            extra[2] = amountInLeft;
            extra[3] = params[4] == LIMIT_BUY ?
                OrderBookLibrary.getAmountOut(amountInLeft, params[1], params[0]) :
                OrderBookLibrary.getAmountOut(amountInLeft, params[0], params[1]);
            amountOutGet += extra[3];
        }

        (extra[0], extra[1]) = params[4] == LIMIT_BUY ? (params[1] + extra[2], params[0].sub(extra[3])) :
        (params[0] + extra[2], params[1].sub(extra[3]));
    }

    function getAmountInForMovePrice(address orderBook, address tokenOut, uint amountOutOffer) external override view
    returns (uint amountInGet, uint[] memory extra) {
        uint[] memory params = new uint[](7);
        address[] memory addresses = new address[](3);
        extra = new uint[](6); //nextReserveIn, nextReserveOut, ammIn, ammOut, orderIn, orderOutWithSubsidyFee
        (addresses[0], addresses[1], addresses[2]) =
            (IOrderBook(orderBook).pair(), IOrderBook(orderBook).baseToken(), IOrderBook(orderBook).quoteToken());
        //reserveBase - reserveQuote
        (params[0], params[1]) = OrderBookLibrary.getReserves(addresses[0], addresses[1], addresses[2]);
        (params[2], params[3]) = IOrderBook(orderBook).getFeeRate(); //protocolFeeRate - subsidyFeeRate
        (params[5], params[4]) = OrderBookLibrary.getDirection(addresses[2], tokenOut);//orderDir - tradeDir
        params[6] = IOrderBook(orderBook).baseDecimal();
        uint amountOutLeft = amountOutOffer;
        amountInGet = 0;
        (uint price, uint amount) = IOrderBook(orderBook).nextBook(params[5], 0);
        while (price != 0) {
            uint amountAmmLeft;
            if (params[4] == LIMIT_BUY) {
                (amountAmmLeft, extra[1], extra[0], extra[3], extra[2]) =
                OrderBookLibrary.getAmountForMovePriceWithAmountOut(params[4], amountOutLeft, params[0], params[1],
                    price, params[6]);
            }
            else {
                (amountAmmLeft, extra[0], extra[1], extra[2], extra[3]) =
                OrderBookLibrary.getAmountForMovePriceWithAmountOut(params[4], amountOutLeft, params[0], params[1],
                    price, params[6]);
            }

            if (amountAmmLeft == 0) {
                break;
            }

            (uint amountInForTake, uint amountOutWithFee, uint communityFee) = OrderBookLibrary.getAmountInForTakePrice
            (params[4], amountAmmLeft, price, params[6], params[2], params[3], amount);
            extra[4] += amountInForTake;
            extra[5] += amountOutWithFee.sub(communityFee);
            amountInGet += amountInForTake;
            amountOutLeft = amountOutLeft.sub(amountOutWithFee.sub(communityFee));
            if (amountOutWithFee == amountAmmLeft) {
                break;
            }

            (price, amount) = IOrderBook(orderBook).nextBook(params[5], price);
        }

        if (amountOutLeft > 0) {
            extra[2] = params[4] == LIMIT_BUY ?
                OrderBookLibrary.getAmountIn(amountOutLeft, params[1], params[0]) :
                OrderBookLibrary.getAmountIn(amountOutLeft, params[0], params[1]);
            amountInGet += extra[2];
            extra[3] = amountOutLeft;
        }

        (extra[0], extra[1]) = params[4] == LIMIT_BUY ? (params[1] + extra[2], params[0].sub(amountOutLeft)) :
        (params[0] + extra[2], params[1].sub(amountOutLeft));
    }
}