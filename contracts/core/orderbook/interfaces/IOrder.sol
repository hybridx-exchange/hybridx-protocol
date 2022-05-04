// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOrder {
    struct OrderDetail {
        uint256 _price;
        uint256 _offer;
        uint256 _remain;
        uint8 _type;
    }
    function initialize(address _admin, address _orderbook) external;
    function add(uint256 tokenId, uint256 amount) external;
    function mint(OrderDetail memory orderDetail, address to) external returns (uint256 tokenId);
    function sub(uint256 tokenId, uint256 amount) external;
    function get(uint256 tokenId) external view returns (OrderDetail memory order);
    function getUserOrders(address user) external view returns (OrderDetail[] memory orders);
}