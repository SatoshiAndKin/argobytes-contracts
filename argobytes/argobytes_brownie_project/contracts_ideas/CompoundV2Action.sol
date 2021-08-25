pragma solidity 0.8.7;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";

// TODO: do we want auth on this with setters? i think no. i think we should just have a simple contract with a constructor. if we need changes, we can deploy a new contract. less methods is less attack surface
contract CompoundV2Action is AbstractERC20Exchange {
    // TODO: helper here that sets allowances and then transfers? i think IUniswapExchange might already have all the methods we need though
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
