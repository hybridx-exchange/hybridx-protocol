// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import './Pair.sol';
import "./interfaces/IPairFactory.sol";

contract PairFactory is IPairFactory {
    address public override config;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor(address _config) {
        config = _config;
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IPair(pair).initialize(token0, token1, config);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function getCodeHash() external pure override returns (bytes32) {
        return keccak256(type(Pair).creationCode);
    }
}
