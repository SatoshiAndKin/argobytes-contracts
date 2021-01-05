// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.4;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

interface ILiquidGasToken is IERC20 {
    // Price Query Functions
    function getEthToTokenInputPrice(uint256 ethSold)
        external
        view
        returns (uint256 tokensBought);

    function getEthToTokenOutputPrice(uint256 tokensBought)
        external
        view
        returns (uint256 ethSold);

    function getTokenToEthInputPrice(uint256 tokensSold)
        external
        view
        returns (uint256 ethBought);

    function getTokenToEthOutputPrice(uint256 ethBought)
        external
        view
        returns (uint256 tokensSold);

    // Liquidity Pool
    function poolTotalSupply() external view returns (uint256);

    function poolTokenReserves() external view returns (uint256);

    function poolBalanceOf(address account) external view returns (uint256);

    function poolTransfer(address recipient, uint256 amount)
        external
        returns (bool);

    function addLiquidity(
        uint256 minLiquidity,
        uint256 maxTokens,
        uint256 deadline
    ) external payable returns (uint256 liquidityCreated);

    function removeLiquidity(
        uint256 amount,
        uint256 minEth,
        uint256 minTokens,
        uint256 deadline
    ) external returns (uint256 ethAmount, uint256 tokenAmount);

    // Buy Tokens
    function ethToTokenSwapInput(uint256 minTokens, uint256 deadline)
        external
        payable
        returns (uint256 tokensBought);

    function ethToTokenTransferInput(
        uint256 minTokens,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256 tokensBought);

    function ethToTokenSwapOutput(uint256 tokensBought, uint256 deadline)
        external
        payable
        returns (uint256 ethSold);

    function ethToTokenTransferOutput(
        uint256 tokensBought,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256 ethSold);

    // Sell Tokens
    function tokenToEthSwapInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline
    ) external returns (uint256 ethBought);

    function tokenToEthTransferInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline,
        address payable recipient
    ) external returns (uint256 ethBought);

    function tokenToEthSwapOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline
    ) external returns (uint256 tokensSold);

    function tokenToEthTransferOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline,
        address payable recipient
    ) external returns (uint256 tokensSold);

    // Events
    event AddLiquidity(
        address indexed provider,
        uint256 indexed eth_amount,
        uint256 indexed token_amount
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256 indexed eth_amount,
        uint256 indexed token_amount
    );
    event TransferLiquidity(
        address indexed from,
        address indexed to,
        uint256 value
    );

    // Minting Tokens
    function mint(uint256 amount) external;

    function mintFor(uint256 amount, address recipient) external;

    function mintToLiquidity(
        uint256 maxTokens,
        uint256 minLiquidity,
        uint256 deadline,
        address recipient
    )
        external
        payable
        returns (
            uint256 tokenAmount,
            uint256 ethAmount,
            uint256 liquidityCreated
        );

    function mintToSell(
        uint256 amount,
        uint256 minEth,
        uint256 deadline
    ) external returns (uint256 ethBought);

    function mintToSellTo(
        uint256 amount,
        uint256 minEth,
        uint256 deadline,
        address payable recipient
    ) external returns (uint256 ethBought);

    // Freeing Tokens
    function free(uint256 amount) external returns (bool success);

    function freeFrom(uint256 amount, address owner)
        external
        returns (bool success);

    // Buying and Freeing Tokens.
    // It is always recommended to check the price for the amount of tokens you intend to buy
    // and then send the exact amount of ether.

    // Will refund excess ether and returns 0 instead of reverting on most errors.
    function buyAndFree(
        uint256 amount,
        uint256 deadline,
        address payable refundTo
    ) external payable returns (uint256 ethSold);

    // Spends all ether (no refunds) to buy and free as many tokens as possible.
    function buyMaxAndFree(uint256 deadline)
        external
        payable
        returns (uint256 tokensBought);


    /// @notice Deploy a contract via create() while buying and freeing `tokenAmount` tokens
    ///         to reduce the gas cost. You need to provide ether to buy the tokens.
    ///         Any excess ether is refunded.
    /// @param tokenAmount The number of tokens bought and freed.
    /// @param deadline The time after which the transaction can no longer be executed.
    ///        Will revert if the current timestamp is after the deadline.
    /// @param bytecode The bytecode of the contract you want to deploy.
    /// @dev Will revert if deadline passed or not enough ether is sent.
    ///      Can't send ether with deployment. Pre-fund the address instead.
    /// @return contractAddress The address where the contract was deployed.
    function deploy(uint256 tokenAmount, uint256 deadline, bytes memory bytecode)
        external
        payable
        returns (address contractAddress);

    /// @notice Deploy a contract via create2() while buying and freeing `tokenAmount` tokens
    ///         to reduce the gas cost. You need to provide ether to buy the tokens.
    ///         Any excess ether is refunded.
    /// @param tokenAmount The number of tokens bought and freed.
    /// @param deadline The time after which the transaction can no longer be executed.
    ///        Will revert if the current timestamp is after the deadline.
    /// @param salt The salt is used for create2() to determine the deployment address.
    /// @param bytecode The bytecode of the contract you want to deploy.
    /// @dev Will revert if deadline passed or not enough ether is sent.
    ///      Can't send ether with deployment. Pre-fund the address instead.
    /// @return contractAddress The address where the contract was deployed.
    function create2(uint256 tokenAmount, uint256 deadline, uint256 salt, bytes memory bytecode)
        external
        payable
        returns (address contractAddress);

    // Optimized Functions
    // !!! USE AT YOUR OWN RISK !!!
    // These functions are gas optimized and intended for experienced users.
    // The function names are constructed to have 3 or 4 leading zero bytes
    // in the function selector.
    // Additionally, all checks have been omitted and need to be done before
    // sending the call if desired.
    // There are also no return values to further save gas.
    // !!! USE AT YOUR OWN RISK !!!
    function mintToSell9630191(uint256 amount) external;

    function mintToSellTo25630722(uint256 amount, address payable recipient)
        external;

    function buyAndFree22457070633(uint256 amount) external payable;
}
