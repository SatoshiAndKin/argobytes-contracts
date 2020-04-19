pragma solidity 0.6.6;

import "./AbstractERC20Exchange.sol";
import "contracts/UniversalERC20.sol";

contract ExampleAction is AbstractERC20Exchange {
    using UniversalERC20 for IERC20;

    function fail() public payable {
        revert("ExampleAction: fail function always reverts");
    }

    function noop() public payable returns (bool) {
        return true;
    }

    function sweep(address payable token) public payable {
        uint256 balance = IERC20(token).universalBalanceOf(address(this));

        IERC20(token).universalTransfer(msg.sender, balance);
    }

    function _tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory)
        internal override
    {
        to;
        dest_token;
        dest_min_tokens;
        dest_max_tokens;
    }

    function _tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory)
        internal override
    {
        to;
        src_token;
        dest_token;
        dest_min_tokens;
        dest_max_tokens;
    }

    function _tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory)
        internal override
    {
        to;
        src_token;
        dest_min_tokens;
        dest_max_tokens;
    }
}
