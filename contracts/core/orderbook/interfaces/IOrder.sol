// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOrder {
    struct OrderDetail {
        uint256 _price;
        uint256 _offer;
        uint256 _remain;
        uint8 _type;
    }

    function mint(OrderDetail memory orderDetail, address to) external returns (uint256 tokenId);
    function burn(uint256 tokenId, uint256 amount) external;
    function get(uint256 tokenId) external view returns (OrderDetail memory order);
}