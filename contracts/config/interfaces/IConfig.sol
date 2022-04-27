// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IConfig {
    function orderNFTByteCode() external view returns (bytes memory bytecode);
    function setOrderNFTByteCode(bytes memory byteCode) external;
    function orderBookByteCode() external view returns (bytes memory bytecode);
    function setOrderBookByteCode(bytes memory byteCode) external;
    function priceStepFactorUpdate(uint newPriceStepFactor) external;
    function protocolFeeRateUpdate(address orderBook, uint newProtocolFeeRate) external;
    function subsidyFeeRateUpdate(address orderBook, uint newSubsidyFeeRate) external;
    function priceStepUpdate(address orderBook, uint newPriceStep) external;
    function protocolFeeRate(address orderBook) external view returns (uint);
    function subsidyFeeRate(address orderBook) external view returns (uint);
    function priceStep(address orderBook, uint price) external view returns (uint);
}