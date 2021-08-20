// SPDX-License-Identifier: You can't license an interface
/* https://github.com/KyberNetwork/smart-contracts/blob/master/contracts/sol6/IKyberNetworkProxy.sol */

/* https://developer.kyber.network/docs/DappsGuide/ */

pragma solidity 0.8.7;

// TODO: we should be able to include a smaller interface, but we need it to be named "ERC20" so that the function signatures match!
// TODO: actually, IERC20 turns into "address" in the function signature
import {IERC20} from "contracts/external/erc20/IERC20.sol";

interface IKyberNetworkProxy {
    /// @notice use token address ETH_TOKEN_ADDRESS for ether
    /// @dev makes a trade between src and dest token and send dest token to destAddress
    /// @param src Src token
    /// @param src_amount amount of src tokens
    /// @param dest   Destination token
    /// @param destAddress Address to send tokens to
    /// @param maxDestAmount A limit on the amount of dest tokens
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade is canceled.
    /// @param wallet_id is the wallet ID to send part of the fees
    /// @return amount of actual dest tokens
    function trade(
        IERC20 src,
        uint256 src_amount,
        IERC20 dest,
        address destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address wallet_id
    ) external payable returns (uint256);

    function tradeWithHint(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable walletId,
        bytes calldata hint
    ) external payable returns (uint256);

    function tradeWithHintAndFee(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable platformWallet,
        uint256 platformFeeBps,
        bytes calldata hint
    ) external payable returns (uint256 destAmount);

    event ExecuteTrade(
        address indexed trader,
        IERC20 src,
        IERC20 dest,
        uint256 actualsrc_amount,
        uint256 actualDestAmount
    );

    function getExpectedRate(
        IERC20 src,
        IERC20 dest,
        uint256 srcQty
    ) external view returns (uint256 expectedRate, uint256 slippageRate);

    function getUserCapInWei(address user) external view returns (uint256);

    function getUserCapInTokenWei(address user, IERC20 token) external view returns (uint256);

    function maxGasPrice() external view returns (uint256);

    function enabled() external view returns (bool);

    function info(bytes32 field) external view returns (uint256);
}
