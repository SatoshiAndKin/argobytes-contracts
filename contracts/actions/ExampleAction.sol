pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

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

    function getAmounts(address token_a, uint256 token_a_amount, address token_b, bytes calldata extra_data)
        external
        returns (Amount[] memory)
    {
        require(token_a != token_b, "token_a should != token_b");

        Amount[] memory amounts = new Amount[](2);

        // get amounts for trading token_a -> token_b
        // use the same amounts that we used in our ETH trades to keep these all around the same value
        amounts[0] = newAmount(token_b, token_a_amount, token_a, extra_data);

        // get amounts for trading token_b -> token_a
        amounts[1] = newAmount(token_a, amounts[0].maker_wei, token_b, extra_data);

        return amounts;
    }

    function newAmount(address maker_address, uint taker_wei, address taker_address, bytes memory extra_data)
        internal override view
        returns (Amount memory)
    {
        revert("wip");
    }
}
