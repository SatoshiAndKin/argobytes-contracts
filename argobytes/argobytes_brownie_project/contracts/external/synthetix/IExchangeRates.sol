// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;

/**
 * @title ExchangeRates interface
 */
interface IExchangeRates {
    function effectiveValue(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey
    ) external view returns (uint256);

    function rateForCurrency(bytes32 currencyKey) external view returns (uint256);

    function ratesForCurrencies(bytes32[] calldata currencyKeys) external view returns (uint256[] memory);

    function rateIsStale(bytes32 currencyKey) external view returns (bool);

    function rateIsFrozen(bytes32 currencyKey) external view returns (bool);

    function anyRateIsStale(bytes32[] calldata currencyKeys) external view returns (bool);

    function getCurrentRoundId(bytes32 currencyKey) external view returns (uint256);

    function effectiveValueAtRound(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        uint256 roundIdForSrc,
        uint256 roundIdForDest
    ) external view returns (uint256);

    function getLastRoundIdBeforeElapsedSecs(
        bytes32 currencyKey,
        uint256 startingRoundId,
        uint256 startingTimestamp,
        uint256 timediff
    ) external view returns (uint256);

    function ratesAndStaleForCurrencies(bytes32[] calldata currencyKeys) external view returns (uint256[] memory, bool);

    function rateAndTimestampAtRound(bytes32 currencyKey, uint256 roundId)
        external
        view
        returns (uint256 rate, uint256 time);

    function lastRateUpdateTimes(bytes32 currencyKey) external view returns (uint256);
}
