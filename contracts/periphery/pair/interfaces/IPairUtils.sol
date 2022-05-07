// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPairUtils {
    function config() external view returns (address);
    function getBestAmountsOut(uint amountIn, address[] calldata paths, uint[] calldata lens) external view returns (
        address[] memory path, uint[] memory amounts, uint[] memory nextReserves);
    function getBestAmountsIn(uint amountOut, address[] calldata paths, uint[] calldata lens) external view returns (
        address[] memory path, uint[] memory amounts, uint[] memory nextReserves);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (
        uint[] memory amounts, uint[] memory nextReserves);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (
        uint[] memory amounts, uint[] memory nextReserves);
}
