// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

contract PriceList {
    uint internal constant LIMIT_BUY = 1;
    uint internal constant LIMIT_SELL = 2;

    mapping(uint => mapping(uint => uint)) private limitOrderPriceListMap;
    mapping(uint => uint) private limitOrderPriceArrayLength;

    function priceLength(uint direction) internal view returns (uint priceArrayLength) {
        priceArrayLength = limitOrderPriceArrayLength[direction];
    }

    function priceLocation(uint direction, uint price) internal view returns (uint preIndex, uint next) {
        (preIndex, next) = (0, limitOrderPriceListMap[direction][0]);
        if (direction == LIMIT_BUY) {
            while(next > price) {
                preIndex = next;
                next = limitOrderPriceListMap[direction][next];
                if (next == 0) {
                    break;
                }
            }
        }
        else if (direction == LIMIT_SELL) {
            while(next < price) {
                preIndex = next;
                next = limitOrderPriceListMap[direction][next];
                if (next == 0) {
                    break;
                }
            }
        }
    }

    function addPrice(uint direction, uint price) internal {
        uint priceArrayLength = limitOrderPriceArrayLength[direction];
        if (priceArrayLength == 0) {
            limitOrderPriceListMap[direction][0] = price;
            limitOrderPriceListMap[direction][price] = 0;
        }
        else {
            (uint preIndex, uint nextIndex) = priceLocation(direction, price);
            limitOrderPriceListMap[direction][preIndex] = price;
            limitOrderPriceListMap[direction][price] = nextIndex;
        }

        limitOrderPriceArrayLength[direction]++;
    }

    function delPrice(uint direction, uint price) internal {
        (uint preIndex, uint nextIndex) = priceLocation(direction, price);
        require(price == nextIndex, 'List: Invalid price');
        limitOrderPriceListMap[direction][preIndex] = limitOrderPriceListMap[direction][nextIndex];
        delete limitOrderPriceListMap[direction][nextIndex];
        limitOrderPriceArrayLength[direction]--;
    }

    function nextPrice(uint direction, uint cur) internal view returns (uint next) {
        next = limitOrderPriceListMap[direction][cur];
    }

    function firstPrice(uint direction) internal view returns (uint first) {
        first = limitOrderPriceListMap[direction][0];
    }
}