// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import './interfaces/IPairUtils.sol';
import '../../core/pair/interfaces/IPairFactory.sol';
import '../../core/pair/libraries/PairLibrary.sol';

contract PairUtils is IPairUtils {
    address public override config;
    constructor(address _config) {
        config = _config;
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return PairLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return PairLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return PairLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts, uint[] memory extra)
    {
        return PairLibrary.getAmountsOutWithExtra(IConfig(config).getPairFactory(), amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts, uint[] memory extra)
    {
        return PairLibrary.getAmountsInWithExtra(IConfig(config).getPairFactory(), amountOut, path);
    }

    function getBestAmountsOut(uint amountIn, address[] memory paths, uint[] memory lens)
        external
        view
        virtual
        override
        returns (address[] memory path, uint[] memory amounts, uint[] memory extra)
    {
        address[][] memory groupedPaths = new address[][](lens.length);
        uint k;
        for (uint i; i<lens.length; i++) {
            groupedPaths[i] = new address[](lens[i]);
            for (uint j; j<groupedPaths[i].length; j++) {
                groupedPaths[i][j] = paths[k++];
            }
        }
        require(paths.length == k, "PairUtils: INVALID_PATHS");
        return PairLibrary.getBestAmountsOut(IConfig(config).getPairFactory(), amountIn, groupedPaths);
    }

    function getBestAmountsIn(uint amountOut, address[] memory paths, uint[] memory lens)
        external
        view
        virtual
        override
        returns (address[] memory path, uint[] memory amounts, uint[] memory extra)
    {
        address[][] memory groupedPaths = new address[][](lens.length);
        uint k;
        for (uint i; i<lens.length; i++) {
            groupedPaths[i] = new address[](lens[i]);
            for (uint j; j<groupedPaths[i].length; j++) {
                groupedPaths[i][j] = paths[k++];
            }
        }
        require(paths.length == k, "PairUtils: INVALID_PATHS");
        return PairLibrary.getBestAmountsIn(IConfig(config).getPairFactory(), amountOut, groupedPaths);
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB) external view override
    returns (uint reserveA, uint reserveB) {
        (reserveA, reserveB,) = PairLibrary.getReserves(IConfig(config).getPairFactory(), tokenA, tokenB);
    }
}
