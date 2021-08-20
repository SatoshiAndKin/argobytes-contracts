// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;

/**
 * @title Synthetix Depot interface
 */
interface IDepot {
    function exchangeEtherForSynths() external payable returns (uint256);

    // function exchangeEtherForSynthsAtRate(uint guaranteedRate) external payable returns (uint);

    // function depositSynths(uint amount) external;

    function synthsReceivedForEther(uint256 amount) external view returns (uint256);

    // function withdrawMyDepositedSynths() external;

    // Deprecated ABI for MAINNET. Only used on Testnets
    // function exchangeEtherForSNX() external payable returns (uint);

    // Deprecated ABI for MAINNET. Only used on Testnets
    // function exchangeEtherForSNXAtRate(uint guaranteedRate) external payable returns (uint);

    // Deprecated ABI for MAINNET. Only used on Testnets
    // function exchangeSynthsForSNX() external payable returns (uint);

    event MaxEthPurchaseUpdated(uint256 amount);
    event FundsWalletUpdated(address newFundsWallet);
    event Exchange(string fromCurrency, uint256 fromAmount, string toCurrency, uint256 toAmount);
    event SynthWithdrawal(address user, uint256 amount);
    event SynthDeposit(address indexed user, uint256 amount, uint256 indexed depositIndex);
    event SynthDepositRemoved(address indexed user, uint256 amount, uint256 indexed depositIndex);
    event SynthDepositNotAccepted(address user, uint256 amount, uint256 minimum);
    event MinimumDepositAmountUpdated(uint256 amount);
    event NonPayableContract(address indexed receiver, uint256 amount);
    event ClearedDeposit(
        address indexed fromAddress,
        address indexed toAddress,
        uint256 fromETHAmount,
        uint256 toAmount,
        uint256 indexed depositIndex
    );
}
