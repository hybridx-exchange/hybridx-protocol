// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../deps/access/Ownable.sol";
import "./interfaces/IConfig.sol";

contract Config is Ownable, IConfig {
    uint public priceStepFactor = 1;          // default is 1 / 10000
    uint public defaultProtocolFeeRate = 30;  // default is 30 / 10000
    uint public defaultSubsidyFeeRate = 50;   // default is 50% of ProtocolFeeRate
    mapping(address => uint) public protocolFeeRateMap;
    mapping(address => uint) public subsidyFeeRateMap;
    mapping(address => uint) public priceStepMap;

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