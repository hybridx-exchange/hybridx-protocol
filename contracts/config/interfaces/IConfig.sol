// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IConfig {
    function priceStepFactorUpdate(uint newPriceStepFactor) external;
    function protocolFeeRateUpdate(address orderBook, uint newProtocolFeeRate) external;
    function subsidyFeeRateUpdate(address orderBook, uint newSubsidyFeeRate) external;
    function priceStepUpdate(address orderBook, uint newPriceStep) external;
    function protocolFeeRate(address orderBook) external view returns (uint);
    function subsidyFeeRate(address orderBook) external view returns (uint);
    function priceStep(address orderBook, uint price) external view returns (uint);
}