// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./pair/interfaces/IPairRouter.sol";
import "./pair/interfaces/IPairUtils.sol";
import "./orderbook/interfaces/IOrderBookRouter.sol";

interface IHybridXRouter is IOrderBookRouter, IPairRouter, IPairUtils {
}