// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

contract OrderQueue {
    //(direction -> price -> orderId -> data ================= <FIFO>)
    mapping(uint => mapping(uint => mapping(uint => uint))) internal limitOrderQueueMap;
    //(direction -> price -> queue front)
    mapping(uint => mapping(uint => uint)) internal limitOrderQueueFront;
    //(direction -> price -> queue rear)
    mapping(uint => mapping(uint => uint)) internal limitOrderQueueRear;

    // Queue length
    function length(uint direction, uint price) internal view returns (uint limitOrderQueueLength) {
        limitOrderQueueLength = limitOrderQueueRear[direction][price] - limitOrderQueueFront[direction][price];
    }

    // push
    function push(uint direction, uint price, uint data) internal {
        uint rear = limitOrderQueueRear[direction][price];
        limitOrderQueueMap[direction][price][rear] = data;
        limitOrderQueueRear[direction][price]++;
    }

    // pop
    function pop(uint direction, uint price) internal returns (uint data) {
        (uint front, uint rear) = (limitOrderQueueFront[direction][price], limitOrderQueueRear[direction][price]);
        if (front != rear){
            data = limitOrderQueueMap[direction][price][front];
            delete limitOrderQueueMap[direction][price][front];
            limitOrderQueueFront[direction][price]++;
        }
    }

    // get the front element
    function peek(uint direction, uint price) internal view returns (uint data) {
        (uint front, uint rear) = (limitOrderQueueFront[direction][price], limitOrderQueueRear[direction][price]);
        if (front != rear) {
            data = limitOrderQueueMap[direction][price][front];
        }
    }

    // get the element by index (only used for test)
    function get(uint direction, uint price, uint index) internal view returns (uint data) {
        (uint front, uint rear) = (limitOrderQueueFront[direction][price], limitOrderQueueRear[direction][price]);
        if (front + index != rear) {
            data = limitOrderQueueMap[direction][price][front+index];
        }
    }

    // del
    function del(uint direction, uint price, uint data) internal {
        (uint front, uint rear) = (limitOrderQueueFront[direction][price], limitOrderQueueRear[direction][price]);
        require(front < rear, 'Queue: Invalid queue');

        uint pre = limitOrderQueueMap[direction][price][front];
        uint cur = pre;
        for (uint i = front + 1; i < rear; i++) {
            if (pre == data) {
                break;
            }

            cur = limitOrderQueueMap[direction][price][i];
            limitOrderQueueMap[direction][price][i] = pre;
            pre = cur;
        }

        require(data == cur, 'Invalid data');
        delete limitOrderQueueMap[direction][price][front];
        limitOrderQueueFront[direction][price]++;
    }
}