// https://github.com/makerdao/developerguides/blob/master/Oasis/intro-to-oasis/intro-to-oasis-maker-otc.md

pragma solidity 0.8.7;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";

contract OasisAction is AbstractERC20Exchange {
    function _tradeEtherToToken(
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens,
        bytes memory
    ) internal override {
        revert("wip");
    }

    function _tradeTokenToToken(
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens,
        bytes memory
    ) internal override {
        revert("wip");
    }

    function _tradeTokenToEther(
        address to,
        address src_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens,
        bytes memory
    ) internal override {
        revert("wip");
    }
}
