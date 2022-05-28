// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IConfig {
    function WETH() external view returns (address);
    function getPairFactory() external view returns (address);
    function setPairFactory(address newPairFactory) external;
    function getOrderBookFactory() external view returns (address);
    function setOrderBookFactory(address newOrderBookFactory) external;
    function getOrderNFTByteCode() external view returns (bytes memory bytecode);
    function setOrderNFTByteCode(bytes memory byteCode) external;
    function getOrderBookByteCode() external view returns (bytes memory bytecode);
    function setOrderBookByteCode(bytes memory byteCode) external;
    function priceStepFactor() external returns (uint);
    function priceStepFactorUpdate(uint newPriceStepFactor) external;
    function priceStepMap(address orderBook) external returns (uint);
    function protocolFeeRateUpdate(address orderBook, uint newProtocolFeeRate) external;
    function subsidyFeeRateUpdate(address orderBook, uint newSubsidyFeeRate) external;
    function priceStepUpdate(address orderBook, uint newPriceStep) external;
    function baseSignificantDigitsUpdate(address orderBook, uint newBaseSignificantDigits) external;
    function quoteSignificantDigitsUpdate(address orderBook, uint newQuoteSignificantDigits) external;
    function protocolFeeRate(address orderBook) external view returns (uint);
    function subsidyFeeRate(address orderBook) external view returns (uint);
    function priceStep(address orderBook, uint price) external view returns (uint);
    function baseSignificantDigits(address orderBook) external view returns (uint);
    function quoteSignificantDigits(address orderBook) external view returns (uint);
}