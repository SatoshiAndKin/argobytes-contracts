// get this working in multiple phases.
// phase 0: operate for flash loans. phase 1: operate for trading. phase 2: operate for liquidating
pragma solidity 0.6.6;

import "../AbstractERC20Exchange.sol";

contract DyDxAction is AbstractERC20Exchange {
    function _tradeEtherToToken(
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens, 
        bytes memory extra_data
    ) internal override {
        revert("wip");
    }

    function _tradeTokenToToken(
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens, 
        bytes memory extra_data
    ) internal override {
        revert("wip");
    }

    function _tradeTokenToEther(
        address to,
        address src_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens, 
        bytes memory extra_data
    ) internal override {
        revert("wip");
    }
}
