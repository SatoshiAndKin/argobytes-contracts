// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;

/* https://docs.uniswap.io/smart-contract-integration/interface#factory-interface */

interface IUniswapFactory {
    event NewExchange(address indexed token, address indexed exchange);

    // Public Variables
    // address public exchangeTemplate;
    function exchangeTemplate() external view returns (address _exchangeTemplate);

    // uint256 public tokenCount;
    function tokenCount() external view returns (uint256 _tokenCount);

    // Create Exchange
    function createExchange(address token) external returns (address exchange);

    // Get Exchange and Token Info
    function getExchange(address token) external view returns (address exchange);

    function getToken(address exchange) external view returns (address token);

    function getTokenWithId(uint256 tokenId) external view returns (address token);

    // Never use
    function initializeFactory(address template) external;
}
