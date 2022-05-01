// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOrderBookRouter {
    function config() external view returns (address);

    //buy with token
    function buyWithToken(
        uint amountOffer,
        uint price,
        address tokenA,
        address tokenB,
        address to,
        uint deadline)
        external
        returns (uint);

    //buy with eth
    function buyWithEth(
        uint price,
        address tokenA,
        address to,
        uint deadline)
        external
        payable
        returns (uint);

    //sell token
    function sellToken(
        uint amountOffer,
        uint price,
        address tokenA,
        address tokenB,
        address to,
        uint deadline)
        external
        returns (uint);

    //sell eth
    function sellEth(
        uint price,
        address tokenB,
        address to,
        uint deadline)
        external
        payable
        returns (uint);

    function getAmountsForBuy(
        uint amountOffer,
        uint price,
        address tokenA,
        address tokenB)
    external view
    returns (uint[] memory amounts);

    function getAmountsForSell(
        uint amountOffer,
        uint price,
        address tokenA,
        address tokenB)
    external view
    returns (uint[] memory amounts);

    function getOrderBook(
        address tokenA,
        address tokenB,
        uint32 limitSize)
    external view
    returns
    (uint price, uint[] memory buyPrices, uint[] memory buyAmounts, uint[] memory sellPrices, uint[] memory
        sellAmounts);
}
