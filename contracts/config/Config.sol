// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../deps/access/Ownable.sol";
import "./interfaces/IConfig.sol";

/**************************************************************************************************************
@title                          config for hybrid protocol
@author                         https://twitter.com/cherideal
@ens                            cherideal.eth
**************************************************************************************************************/
contract Config is Ownable, IConfig {
    uint public priceStepFactor = 1;          // default is 1 / 10000
    uint public defaultProtocolFeeRate = 30;  // default is 30 / 10000
    uint public defaultSubsidyFeeRate = 50;   // default is 50% of ProtocolFeeRate
    mapping(address => uint) public protocolFeeRateMap;
    mapping(address => uint) public subsidyFeeRateMap;
    mapping(address => uint) public priceStepMap;
    bytes internal orderNFTByteCode;
    bytes internal orderBookByteCode;

    address public override WETH;
    address internal pairFactory;
    address internal orderBookFactory;
    constructor(address _WETH) {
        WETH = _WETH;
    }

    function getPairFactory() external view override returns (address) {
        require(pairFactory != address(0), 'Pair Factory Address not set');
        return pairFactory;
    }

    function setPairFactory(address newPairFactory) external override {
        require(pairFactory == address(0), 'Pair Factory Address set already');
        pairFactory = newPairFactory;
    }

    function getOrderBookFactory() external view override returns (address) {
        return orderBookFactory;
    }

    function setOrderBookFactory(address newOrderBookFactory) external override {
        require(orderBookFactory == address(0), 'Order Book Factory Address set already');
        orderBookFactory = newOrderBookFactory;
    }

    function getOrderNFTByteCode() external view override returns (bytes memory bytecode) {
        require(orderNFTByteCode.length != 0, 'Order NFT Bytecode not set');
        bytecode = orderNFTByteCode;
    }

    function setOrderNFTByteCode(bytes memory byteCode) external override onlyOwner {
        require(orderNFTByteCode.length == 0, 'Order NFT Bytecode set already');
        orderNFTByteCode = byteCode;
    }

    function getOrderBookByteCode() external view override returns (bytes memory bytecode) {
        require(orderBookByteCode.length != 0, 'Order Book Bytecode not set');
        bytecode = orderBookByteCode;
    }

    function setOrderBookByteCode(bytes memory byteCode) external override onlyOwner {
        require(orderBookByteCode.length == 0, 'Order Book Bytecode set already');
        orderBookByteCode = byteCode;
    }

    function priceStepFactorUpdate(uint newPriceStepFactor) external override onlyOwner {
        require(newPriceStepFactor > 0 && newPriceStepFactor <= 100, "Invalid Price Step Factor"); //max 100, min 1
        priceStepFactor = newPriceStepFactor;
    }

    function protocolFeeRateUpdate(address orderBook, uint newProtocolFeeRate) external override onlyOwner {
        require(newProtocolFeeRate <= 30, "Invalid Fee Rate"); //max fee is 0.3%, default is 0.3%
        protocolFeeRateMap[orderBook] = newProtocolFeeRate;
    }

    function subsidyFeeRateUpdate(address orderBook, uint newSubsidyFeeRate) external override onlyOwner {
        require(newSubsidyFeeRate <= 100, "Invalid Fee Rate"); //max is 100% of protocolFeeRate
        subsidyFeeRateMap[orderBook] = newSubsidyFeeRate;
    }

    function priceStepUpdate(address orderBook, uint newPriceStep) external override onlyOwner {
        require(newPriceStep > 0, "Invalid Price Step");
        priceStepMap[orderBook] = newPriceStep;
    }

    //get protocol fee rate
    function protocolFeeRate(address orderBook) external override view returns (uint) {
        if (protocolFeeRateMap[orderBook] != 0) return protocolFeeRateMap[orderBook];
        return defaultProtocolFeeRate;
    }

    //get subsidy fee rate
    function subsidyFeeRate(address orderBook) external override view returns (uint) {
        if (subsidyFeeRateMap[orderBook] != 0) return subsidyFeeRateMap[orderBook];
        return defaultSubsidyFeeRate;
    }

    //get price step
    function priceStep(address orderBook, uint price) external override view returns (uint) {
        if (priceStepMap[orderBook] != 0) return priceStepMap[orderBook];
        return price <= 10000 ? 1 : (price / 10000) * priceStepFactor;
    }
}