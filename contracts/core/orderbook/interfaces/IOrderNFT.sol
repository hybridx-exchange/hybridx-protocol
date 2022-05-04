// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IOrder.sol";
import "../../../deps/interfaces/IERC721.sol";
import "../../../deps/extensions/IERC721Burnable.sol";
import "../../../deps/extensions/IERC721Enumerable.sol";
import "../../../deps/interfaces/IERC721Metadata.sol";
import "../../../deps/access/IAccessControlEnumerable.sol";

interface IOrderNFT is IOrder, IERC721Burnable, IERC721Enumerable, IERC721Metadata, IAccessControlEnumerable {
}