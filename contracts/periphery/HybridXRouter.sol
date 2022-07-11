// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../config/interfaces/IConfig.sol";
import "./orderbook/interfaces/IOrderBookRouter.sol";
import "./pair/interfaces/IPairUtils.sol";
import "./pair/interfaces/IPairRouter.sol";
import "./Proxy.sol";
import "../deps/access/Ownable.sol";

//Merge the interface of OrderBookRouter.sol/PairRouter.sol/PairUtils.sol files for unified operation and reduced authorization
contract HybridXRouter is Proxy {
    address public config;

    receive() external payable override {
        assert(msg.sender == IConfig(config).wETH()); // only accept ETH via fallback from the wETH contract
    }

    mapping(bytes4 => address) public functionMap;
    function _implementation() internal view override returns (address) {
        address client = functionMap[msg.sig];
        require(client != address(0), 'HybridXRouter: Function Not Exist');
        return client;
    }

    constructor(address _config) {
        config = _config;
    }

    function bindFunctions(address clientAddress, bytes4[] memory functionIds) external {
        require(msg.sender == Ownable(config).owner(), 'HybridXRouter: FORBIDDEN');
        for (uint i; i<functionIds.length; i++) {
            require(functionMap[functionIds[i]] == address(0));
            functionMap[functionIds[i]] = clientAddress;
        }
    }
}