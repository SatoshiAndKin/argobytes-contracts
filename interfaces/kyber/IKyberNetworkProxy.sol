/* https://github.com/KyberNetwork/smart-contracts/blob/master/contracts/KyberNetworkProxy.sol */

/* https://developer.kyber.network/docs/DappsGuide/ */

pragma solidity 0.6.6;

// TODO: we should be able to include a smaller interface, but we need it to be named "ERC20" so that the function signatures match!
// TODO: actually, IERC20 turns into "address" in the function signature
import "OpenZeppelin/openzeppelin-contracts@3.0.0-rc.1/contracts/token/ERC20/IERC20.sol";

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
        uint src_amount,
        IERC20 dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address wallet_id
    )
        external
        payable
        returns(uint);

    event ExecuteTrade(address indexed trader, IERC20 src, IERC20 dest, uint actualsrc_amount, uint actualDestAmount);

    function getExpectedRate(IERC20 src, IERC20 dest, uint srcQty)
        external view
        returns(uint expectedRate, uint slippageRate);

    function getUserCapInWei(address user) external view returns(uint);

    function getUserCapInTokenWei(address user, IERC20 token) external view returns(uint);

    function maxGasPrice() external view returns(uint);

    function enabled() external view returns(bool);

    function info(bytes32 field) external view returns(uint);
}
