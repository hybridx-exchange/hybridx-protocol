// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../interfaces/IOrderBook.sol";
import "../interfaces/IOrderBookFactory.sol";
import "../../pair/interfaces/IPairFactory.sol";
import "../../pair/interfaces/IPair.sol";
import "../../config/interfaces/IConfig.sol";
import "../../../deps/access/Ownable.sol";
import "../../../deps/libraries/Math.sol";
import "../../../deps/libraries/SafeMath.sol";

library OrderBookLibrary {
    using SafeMath for uint;

    uint internal constant LIMIT_BUY = 1;
    uint internal constant LIMIT_SELL = 2;

    function getOppositeDirection(uint direction) internal pure returns (uint opposite) {
        opposite = direction == LIMIT_BUY ? LIMIT_SELL : direction == LIMIT_SELL ? LIMIT_BUY : 0;
    }

    function getOwner(address factory) internal view returns (address owner) {
        owner = Ownable(IOrderBookFactory(factory).config()).owner();
    }

    //get quote amount with base amount at price --- y = x * p / x_decimal
    function getQuoteAmountWithBaseAmountAtPrice(uint amountBase, uint price, uint baseDecimal) internal pure
    returns (uint amountGet) {
        amountGet = amountBase.mul(price).div(10 ** baseDecimal);
    }

    //get base amount with quote amount at price --- x = y * x_decimal / p
    function getBaseAmountWithQuoteAmountAtPrice(uint amountQuote, uint price, uint baseDecimal) internal pure
    returns (uint amountGet) {
        amountGet = amountQuote.mul(10 ** baseDecimal).div(price);
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

    // fetches and sorts the reserves for a pair
    function getReserves(address pair, address tokenA, address tokenB) internal view
    returns (uint112 reserveA, uint112 reserveB) {
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        address token0 = tokenA < tokenB ? tokenA : tokenB;
        require(token0 != address(0), 'ZERO_ADDRESS');
        (uint112 reserve0, uint112 reserve1,) = pair != address(0) ? IPair(pair).getReserves() : (0, 0, 0);
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // get lp price
    function getPrice(uint reserveBase, uint reserveQuote, uint baseDecimal) internal pure returns (uint price) {
        if (reserveBase != 0) {
            price = reserveQuote.mul(10 ** baseDecimal) / reserveBase;
        }
    }

    function getPair(address config, address tokenA, address tokenB) internal view returns (address pair) {
        address pairFactory = IConfig(config).getPairFactory();
        if (pairFactory != address(0)){
            return IPairFactory(pairFactory).getPair(tokenA, tokenB);
        }
    }

    // Make up for the LP price error caused by the loss of precision,
    // increase the LP price a bit, and ensure that the buy order price is less than or equal to the LP price
    function getFixAmountForMovePriceUp(uint _amountLeft, uint _amountAmmQuote,
        uint reserveBase, uint reserveQuote, uint targetPrice, uint baseDecimal) internal pure
    returns (uint amountLeft, uint amountAmmQuote, uint amountQuoteFix) {
        uint curPrice = getPrice(reserveBase, reserveQuote, baseDecimal);
        // y' = x.p2 - x.p1, x does not change, increase y, make the price bigger
        if (curPrice < targetPrice) {
            amountQuoteFix = (reserveBase.mul(targetPrice).div(10 ** baseDecimal)
                .sub(reserveBase.mul(curPrice).div(10 ** baseDecimal)));
            amountQuoteFix = amountQuoteFix > 0 ? amountQuoteFix : 1;
            require(_amountLeft >= amountQuoteFix, "Not Enough Output Amount");
            (amountLeft, amountAmmQuote) = (_amountLeft.sub(amountQuoteFix), _amountAmmQuote + amountQuoteFix);
        }
        else {
            (amountLeft, amountAmmQuote) = (_amountLeft, _amountAmmQuote);
        }
    }

    // Make up for the LP price error caused by the loss of precision,
    // reduce the LP price a bit, and ensure that the order price is greater than or equal to the LP price
    function getFixAmountForMovePriceDown(uint _amountLeft, uint _amountAmmBase,
        uint reserveBase, uint reserveQuote, uint targetPrice, uint baseDecimal) internal pure
    returns (uint amountLeft, uint amountAmmBase, uint amountBaseFix) {
        uint curPrice = getPrice(reserveBase, reserveQuote, baseDecimal);
        //x' = y/p1 - y/p2, y is unchanged, increasing x makes the price smaller
        if (curPrice > targetPrice) {
            amountBaseFix = (reserveQuote.mul(10 ** baseDecimal).div(targetPrice)
            .sub(reserveQuote.mul(10 ** baseDecimal).div(curPrice)));
            amountBaseFix = amountBaseFix > 0 ? amountBaseFix : 1;
            require(_amountLeft >= amountBaseFix, "Not Enough Input Amount");
            (amountLeft, amountAmmBase) = (_amountLeft.sub(amountBaseFix), _amountAmmBase + amountBaseFix);
        }
        else {
            (amountLeft, amountAmmBase) = (_amountLeft, _amountAmmBase);
        }
    }

    //sqrt(9*y*y + 3988000*x*y*price)
    function getSection1ForPriceUp(uint reserveIn, uint reserveOut, uint price, uint baseDecimal) internal pure
    returns (uint section1) {
        section1 = Math.sqrt(reserveOut.mul(reserveOut).mul(9).add(reserveIn.mul(reserveOut).mul(3988000).mul
        (price).div(10** baseDecimal)));
    }

    //sqrt(9*x*x + 3988000*x*y/price)
    function getSection1ForPriceDown(uint reserveIn, uint reserveOut, uint price, uint baseDecimal) internal pure
    returns (uint section1) {
        section1 = Math.sqrt(reserveIn.mul(reserveIn).mul(9).add(reserveIn.mul(reserveOut).mul(3988000).mul
        (10** baseDecimal).div(price)));
    }

    //amountIn = (sqrt(9*x*x + 3988000*x*y/price)-1997*x)/1994 = (sqrt(x*(9*x + 3988000*y/price))-1997*x)/1994
    //amountOut = y-(x+amountIn)*price
    function getAmountForMovePrice(uint direction, uint amountIn, uint reserveBase, uint reserveQuote,
        uint price, uint baseDecimal) internal pure
    returns (uint amountInLeft, uint amountBase, uint amountQuote, uint reserveBaseNew, uint reserveQuoteNew) {
        if (direction == LIMIT_BUY) {
            uint section1 = getSection1ForPriceUp(reserveBase, reserveQuote, price, baseDecimal);
            uint section2 = reserveQuote.mul(1997);
            amountQuote = section1 > section2 ? (section1 - section2).div(1994) : 0;
            amountQuote = amountQuote > amountIn ? amountIn : amountQuote;
            amountBase = amountQuote == 0 ? 0 : getAmountOut(amountQuote, reserveQuote, reserveBase);//此处重复计算了0.3%的手续费?
            (amountInLeft, reserveBaseNew, reserveQuoteNew) =
                (amountIn - amountQuote, reserveBase - amountBase, reserveQuote + amountQuote);
        }
        else if (direction == LIMIT_SELL) {
            uint section1 = getSection1ForPriceDown(reserveBase, reserveQuote, price, baseDecimal);
            uint section2 = reserveBase.mul(1997);
            amountBase = section1 > section2 ? (section1 - section2).div(1994) : 0;
            amountBase = amountBase > amountIn ? amountIn : amountBase;
            amountQuote = amountBase == 0 ? 0 : getAmountOut(amountBase, reserveBase, reserveQuote);
            (amountInLeft, reserveBaseNew, reserveQuoteNew) =
                (amountIn - amountBase, reserveBase + amountBase, reserveQuote - amountQuote);
        }
        else {
            (amountInLeft, reserveBaseNew, reserveQuoteNew) = (amountIn, reserveBase, reserveQuote);
        }
    }

    //amountIn = (sqrt(9*x*x + 3988000*x*y/price)-1997*x)/1994 = (sqrt(x*(9*x + 3988000*y/price))-1997*x)/1994
    //amountOut = y-(x+amountIn)*price
    function getAmountForMovePriceWithAmountOut(uint direction, uint amountOut, uint reserveBase, uint reserveQuote,
        uint price, uint baseDecimal) internal pure
    returns (uint amountOutLeft, uint amountBase, uint amountQuote, uint reserveBaseNew, uint reserveQuoteNew) {
        if (direction == LIMIT_BUY) {
            uint section1 = getSection1ForPriceUp(reserveBase, reserveQuote, price, baseDecimal);
            uint section2 = reserveQuote.mul(1997);
            amountQuote = section1 > section2 ? (section1 - section2).div(1994) : 0;
            amountBase = amountQuote == 0 ? 0 : getAmountOut(amountQuote, reserveQuote, reserveBase);
            if (amountBase > amountOut) {
                amountBase = amountOut;
                amountQuote = getAmountIn(amountBase, reserveQuote, reserveBase);
            }
            (amountOutLeft, reserveBaseNew, reserveQuoteNew) =
                (amountOut - amountBase, reserveBase - amountBase, reserveQuote + amountQuote);
        }
        else if (direction == LIMIT_SELL) {
            uint section1 = getSection1ForPriceDown(reserveBase, reserveQuote, price, baseDecimal);
            uint section2 = reserveBase.mul(1997);
            amountBase = section1 > section2 ? (section1 - section2).div(1994) : 0;
            amountQuote = amountBase == 0 ? 0 : getAmountOut(amountBase, reserveBase, reserveQuote);
            if (amountQuote > amountOut) {
                amountQuote = amountOut;
                amountBase = getAmountIn(amountQuote, reserveBase, reserveQuote);
            }
            (amountOutLeft, reserveBaseNew, reserveQuoteNew) =
            (amountOut - amountQuote, reserveBase + amountBase, reserveQuote - amountQuote);
        }
        else {
            (amountOutLeft, reserveBaseNew, reserveQuoteNew) = (amountOut, reserveBase, reserveQuote);
        }
    }

    // get the output after taking the order using amountInOffer
    // The protocol fee should be included in the amountOutWithFee
    function getAmountOutForTakePrice(uint tradeDir, uint amountInOffer, uint price, uint baseDecimal,
        uint protocolFeeRate, uint subsidyFeeRate, uint orderAmount) internal pure
    returns (uint amountInUsed, uint amountOutWithFee, uint communityFee) {
        uint fee;
        if (tradeDir == LIMIT_BUY) { //buy (quoteToken == tokenIn, swap quote token to base token)
            //amountOut = amountInOffer / price
            uint amountOut = getBaseAmountWithQuoteAmountAtPrice(amountInOffer, price, baseDecimal);
            if (amountOut.mul(10000) <= orderAmount.mul(10000-protocolFeeRate)) { //amountOut <= orderAmount * (1-0.3%)
                amountInUsed = amountInOffer;
                fee = amountOut.mul(protocolFeeRate).div(10000);
                amountOutWithFee = amountOut + fee;
            }
            else {
                amountOut = orderAmount.mul(10000-protocolFeeRate).div(10000);
                //amountIn = amountOutWithoutFee * price
                amountInUsed = getQuoteAmountWithBaseAmountAtPrice(amountOut, price, baseDecimal);
                amountOutWithFee = orderAmount;
                fee = amountOutWithFee.sub(amountOut);
            }
        }
        else if (tradeDir == LIMIT_SELL) { //sell (quoteToken == tokenOut, swap base token to quote token)
            //amountOut = amountInOffer * price ========= match limit buy order
            uint amountOut = getQuoteAmountWithBaseAmountAtPrice(amountInOffer, price, baseDecimal);
            if (amountOut.mul(10000) <= orderAmount.mul(10000-protocolFeeRate)) { //amountOut <= orderAmount * (1-0.3%)
                amountInUsed = amountInOffer;
                fee = amountOut.mul(protocolFeeRate).div(10000);
                amountOutWithFee = amountOut + fee;
            }
            else {
                amountOut = orderAmount.mul(10000-protocolFeeRate).div(10000);
                //amountIn = amountOutWithoutFee / price
                amountInUsed = getBaseAmountWithQuoteAmountAtPrice(amountOut, price, baseDecimal);
                amountOutWithFee = orderAmount;
                fee = amountOutWithFee - amountOut;
            }
        }

        // (fee * 100 - fee * subsidyFeeRate) / 100
        communityFee = (fee.mul(100).sub(fee.mul(subsidyFeeRate))).div(100);
    }

    //get the input after taking the order with amount out
    function getAmountInForTakePrice(uint tradeDir, uint amountOutExpect, uint price, uint baseDecimal,
        uint protocolFeeRate, uint subsidyFeeRate, uint orderAmount) internal pure
    returns (uint amountIn, uint amountOutWithFee, uint communityFee) {
        uint orderProtocolFeeAmount = orderAmount.mul(protocolFeeRate).div(10000);
        uint orderSubsidyFeeAmount = orderProtocolFeeAmount.mul(subsidyFeeRate).div(100);
        uint orderAmountWithSubsidyFee = orderAmount.sub(orderProtocolFeeAmount.sub(orderSubsidyFeeAmount));
        uint amountOutWithoutFee;
        if (orderAmountWithSubsidyFee <= amountOutExpect) { //take all amount of order
            amountOutWithFee = orderAmount;
            communityFee = amountOutWithFee.sub(orderAmountWithSubsidyFee);
            amountOutWithoutFee = orderAmountWithSubsidyFee.sub(orderSubsidyFeeAmount);
        }
        else {
            orderAmountWithSubsidyFee = amountOutExpect;
            amountOutWithFee = orderAmountWithSubsidyFee.mul(1000000).div(1000000 - protocolFeeRate * subsidyFeeRate);
            amountOutWithoutFee = orderAmountWithSubsidyFee.mul(100).mul(10000 - protocolFeeRate).
                div(1000000 - protocolFeeRate * subsidyFeeRate);
            communityFee = amountOutWithFee.sub(orderAmountWithSubsidyFee);
        }

        if (tradeDir == LIMIT_BUY) {
            amountIn = getQuoteAmountWithBaseAmountAtPrice(amountOutWithoutFee, price, baseDecimal);
        }
        else if (tradeDir == LIMIT_SELL) {
            amountIn = getBaseAmountWithQuoteAmountAtPrice(amountOutWithoutFee, price, baseDecimal);
        }
    }

    /**************************************************************************************************************
    @param orderBook               address of order book contract
    @param amountOffer             amount offered for limit order
    @param price                   price of limit order
    @param reserveBase             reserve amount of base token
    @param reserveQuote            reserve amount of quote token
    @return amounts                [amm amount in, amm amount out, order amount in, order amount out with subsidy fee,
                                    community fee, amount left, amount expert, price to]
**************************************************************************************************************/
    function getAmountsForBuyLimitOrder(
        address orderBook,
        uint amountOffer,
        uint price,
        uint reserveBase,
        uint reserveQuote)
    internal
    view
    returns (uint[] memory amounts) {
        //get sell limit orders within a price range
        (uint[] memory priceArray, uint[] memory amountArray) =
            IOrderBook(orderBook).rangeBook(OrderBookLibrary.LIMIT_SELL, price);
        uint[] memory params = new uint[](5);
        (params[0], params[1], params[2], params[3], params[4]) = (
            IOrderBook(orderBook).baseDecimal(),
            IConfig(IOrderBook(orderBook).config()).protocolFeeRate(orderBook),
            IConfig(IOrderBook(orderBook).config()).subsidyFeeRate(orderBook),
            reserveBase,
            reserveQuote);

        amounts = new uint[](8);
        amounts[5] = amountOffer;

        //See if it is necessary to take orders
        for (uint i=0; i<priceArray.length; i++) {
            uint amountBaseUsed;
            uint amountQuoteUsed;
            uint amountAmmLeft;
            //First calculate the amount in consumed from LP price to order price
            (amountAmmLeft, amountBaseUsed, amountQuoteUsed, params[3], params[4]) =
            OrderBookLibrary.getAmountForMovePrice(
                OrderBookLibrary.LIMIT_BUY, amounts[5], reserveBase, reserveQuote, priceArray[i], params[0]);

            //Calculate the amount of quote that will actually be consumed in amm
            amounts[0] = amountQuoteUsed;
            //Then calculate the amount of Base obtained from this moving price
            amounts[1] = amountBaseUsed;
            if (amountAmmLeft == 0) {
                amounts[5] = 0;  //avoid getAmountForMovePrice recalculation
                break;
            }

            //Calculate the amount of quote required to consume a pending order at a price
            (uint amountInForTake, uint amountOutWithFee, uint communityFee) =
            OrderBookLibrary.getAmountOutForTakePrice(
                OrderBookLibrary.LIMIT_BUY, amountAmmLeft, priceArray[i],
                params[0], params[1], params[2], amountArray[i]);
            amounts[2] += amountInForTake;
            amounts[3] += amountOutWithFee.sub(communityFee);
            amounts[4] += communityFee;
            if (amountInForTake == amountAmmLeft) {
                amounts[5] = 0; //avoid getAmountForMovePrice recalculation
                break;
            }
            amounts[5] = amounts[5].sub(amountInForTake);
        }

        if (amounts[5] > 0 && (priceArray.length == 0 || price > priceArray[priceArray.length-1])) {
            uint amountBaseUsed;
            uint amountQuoteUsed;
            (amounts[5], amountBaseUsed, amountQuoteUsed, params[3], params[4]) =
            OrderBookLibrary.getAmountForMovePrice(
                OrderBookLibrary.LIMIT_BUY, amounts[5], reserveBase, reserveQuote, price, params[0]);
            amounts[0] = amountQuoteUsed;
            amounts[1] = amountBaseUsed;
        }

        if (amounts[1] > 0 && amounts[5] > 0) {
            uint amountQuoteFix;
            (amounts[5], amounts[0], amountQuoteFix) =
            OrderBookLibrary.getFixAmountForMovePriceUp(amounts[5], amounts[0], params[3], params[4],
                price, params[0]);
            amounts[7] = OrderBookLibrary.getPrice(params[3], params[4] + amountQuoteFix, params[0]);
        }
        else {
            amounts[7] = OrderBookLibrary.getPrice(params[3], params[4], params[0]);
        }

        amounts[6] = amounts[5].mul(10000-params[1]).mul(10 ** params[0]).div(price).div(10000);
    }

    /**************************************************************************************************************
    @param orderBook               address of order book contract
    @param amountOffer             amount offered for limit order
    @param price                   price of limit order
    @param reserveBase             reserve amount of base token
    @param reserveQuote            reserve amount of quote token
    @return amounts                [amm amount in, amm amount out, order amount in, order amount out with subsidy fee,
                                    community fee, amount left, amount expect, price to]
    **************************************************************************************************************/
    function getAmountsForSellLimitOrder(
        address orderBook,
        uint amountOffer,
        uint price,
        uint reserveBase,
        uint reserveQuote)
    internal
    view
    returns (uint[] memory amounts) {
        //get buy limit orders within a price range
        (uint[] memory priceArray, uint[] memory amountArray) =
            IOrderBook(orderBook).rangeBook(OrderBookLibrary.LIMIT_BUY, price);
        uint[] memory params = new uint[](5);
        (params[0], params[1], params[2], params[3], params[4]) = (
            IOrderBook(orderBook).baseDecimal(),
            IConfig(IOrderBook(orderBook).config()).protocolFeeRate(orderBook),
            IConfig(IOrderBook(orderBook).config()).subsidyFeeRate(orderBook),
            reserveBase,
            reserveQuote);
        amounts = new uint[](8);
        amounts[5] = amountOffer;

        //See if it is necessary to take orders
        for (uint i=0; i<priceArray.length; i++) {
            uint amountBaseUsed;
            uint amountQuoteUsed;
            uint amountAmmLeft;
            //First calculate the amount in consumed from LP price to order price
            (amountAmmLeft, amountBaseUsed, amountQuoteUsed, params[3], params[4]) =
            OrderBookLibrary.getAmountForMovePrice(
                OrderBookLibrary.LIMIT_SELL, amounts[5], reserveBase, reserveQuote, priceArray[i], params[0]);
            amounts[0] = amountBaseUsed;
            amounts[1] = amountQuoteUsed;
            if (amountAmmLeft == 0) {
                amounts[5] = 0;  //avoid getAmountForMovePrice recalculation
                break;
            }

            //Calculate the amount of base required to consume a pending order at a price
            (uint amountInForTake, uint amountOutWithFee, uint communityFee) =
            OrderBookLibrary.getAmountOutForTakePrice(
                OrderBookLibrary.LIMIT_SELL, amountAmmLeft, priceArray[i],
                params[0], params[1], params[2], amountArray[i]);
            amounts[2] += amountInForTake;
            amounts[3] += amountOutWithFee.sub(communityFee);
            amounts[4] += communityFee;
            if (amountInForTake == amountAmmLeft) {
                amounts[5] = 0; //avoid getAmountForMovePrice recalculation
                break;
            }
            amounts[5] = amounts[5].sub(amountInForTake);
        }

        if (amounts[5] > 0 && (priceArray.length == 0 || price < priceArray[priceArray.length-1])){
            uint amountBaseUsed;
            uint amountQuoteUsed;
            (amounts[5], amountBaseUsed, amountQuoteUsed, params[3], params[4]) =
            OrderBookLibrary.getAmountForMovePrice(
                OrderBookLibrary.LIMIT_SELL, amounts[5], reserveBase, reserveQuote, price, params[0]);
            amounts[0] = amountBaseUsed;
            amounts[1] = amountQuoteUsed;
        }

        if (amounts[0] > 0 && amounts[5] > 0) {
            uint amountBaseFix;
            (amounts[5], amounts[0], amountBaseFix) =
            OrderBookLibrary.getFixAmountForMovePriceDown(amounts[5], amounts[0], params[3], params[4],
                price, params[0]);
            amounts[7] = OrderBookLibrary.getPrice(params[3] + amountBaseFix, params[4], params[0]);
        }
        else {
            amounts[7] = OrderBookLibrary.getPrice(params[3], params[4], params[0]);
        }

        amounts[6] = amounts[5].mul(10000-params[1]).mul(price).div(10000).div(10 ** params[0]);
    }
}