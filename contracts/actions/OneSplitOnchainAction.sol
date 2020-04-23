pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IERC20} from "contracts/UniversalERC20.sol";
import {IOneSplit} from "interfaces/onesplit/IOneSplit.sol";

contract OneSplitOnchainAction is AbstractERC20Exchange {

    IOneSplit _one_split;
    address constant internal ETH_ON_ONESPLIT = address(0x0);

    constructor(address one_split) public {
        _one_split = IOneSplit(one_split);
    }

    // https://github.com/CryptoManiacsZone/1split/blob/master/contracts/IOneSplit.sol
    function encodeExtraData(uint256 parts, uint256 disable_flags) external pure returns (bytes memory encoded) {
        encoded = abi.encode(parts, disable_flags);
    }

    // TODO: helper here that sets allowances and then transfers? i think IUniswapExchange might already have all the methods we need though
    function _tradeEtherToToken(
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 /* dest_max_tokens */,
        bytes memory extra_data
    ) internal override {
        (uint256 parts, uint256 disable_flags) = abi.decode(extra_data, (uint256, uint256));

        uint256 src_balance = address(this).balance;
        require(src_balance > 0, "OneSplitAction._tradeEtherToToken: NO_ETH_BALANCE");

        // no approvals are necessary since we are using ETH

        // calculate the amounts
        // TODO: this is MUCH cheaper to do off chain, but then we don't get the dynamic routing
        (uint256 return_amount, uint256[] memory distribution) = _one_split.getExpectedReturn(
            IERC20(ETH_ON_ONESPLIT),
            IERC20(dest_token),
            src_balance,
            parts,
            disable_flags
        );

        require(return_amount > dest_min_tokens, "OneSplitAction._tradeEtherToToken: LOW_EXPECTED_RETURN");

        // do the actual swap (and send the ETH along as value)
        _one_split.swap{value: src_balance}(IERC20(ETH_ON_ONESPLIT), IERC20(dest_token), src_balance, dest_min_tokens, distribution, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(dest_balance >= dest_min_tokens, "OneSplitAction._tradeEtherToToken: LOW_DEST_BALANCE");

        IERC20(dest_token).transfer(to, dest_balance);
    }

    function _tradeTokenToToken(
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 /* dest_max_tokens */,
        bytes memory extra_data
    ) internal override {
        (uint256 parts, uint256 disable_flags) = abi.decode(extra_data, (uint256, uint256));

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(src_balance > 0, "OneSplitAction._tradeTokenToToken: NO_SRC_BALANCE");

        // approve tokens
        IERC20(src_token).approve(address(_one_split), src_balance);

        // calculate the amounts
        // TODO: this is MUCH cheaper to do off chain, but then we don't get the dynamic routing
        (uint256 return_amount, uint256[] memory distribution) = _one_split.getExpectedReturn(
            IERC20(src_token),
            IERC20(dest_token),
            src_balance,
            parts,
            disable_flags
        );

        require(return_amount > dest_min_tokens, "OneSplitAction._tradeTokenToToken: LOW_EXPECTED_RETURN");

        // do the actual swap
        _one_split.swap(IERC20(src_token), IERC20(dest_token), src_balance, dest_min_tokens, distribution, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(dest_balance >= dest_min_tokens, "OneSplitAction._tradeTokenToToken: LOW_DEST_BALANCE");

        IERC20(dest_token).transfer(to, dest_balance);
    }

    function _tradeTokenToEther(
        address to,
        address src_token,
        uint256 dest_min_tokens,
        uint256 /* dest_max_tokens */,
        bytes memory extra_data
    ) internal override {
        (uint256 parts, uint256 disable_flags) = abi.decode(extra_data, (uint256, uint256));

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(src_balance > 0, "OneSplitAction._tradeTokenToEther: NO_SRC_BALANCE");

        // approve tokens
        IERC20(src_token).approve(address(_one_split), src_balance);

        // calculate the amounts
        // TODO: this is MUCH cheaper to do off chain, but then we don't get the dynamic routing
        (uint256 return_amount, uint256[] memory distribution) = _one_split.getExpectedReturn(
            IERC20(src_token),
            IERC20(ETH_ON_ONESPLIT),
            src_balance,
            parts,
            disable_flags
        );

        require(return_amount > dest_min_tokens, "OneSplitAction._tradeTokenToEther: LOW_EXPECTED_RETURN");

        // do the actual swap
        // TODO: do we need to pass dest_min_tokens since we did the check above? maybe just pass 0 or 1
        _one_split.swap(IERC20(src_token), IERC20(ETH_ON_ONESPLIT), src_balance, dest_min_tokens, distribution, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = address(this).balance;
        require(dest_balance >= dest_min_tokens, "OneSplitAction._tradeTokenToEther: LOW_DEST_BALANCE");

        // TODO: don't use transfer. use call instead. and search for anywhere else we use transfer, too
        payable(to).transfer(dest_balance);
    }

    // TODO: _tradeUniversal instead of the above functions? it would have more if/elses, which makes it harder to reason about. probably higher gas too. but less gas to deploy.

    struct Amount {
        uint256 maker_wei;
        address maker_address;
        uint256 taker_wei;
        address taker_address;
    }

    function get_amounts(address token_a, uint256 eth_amount, address[] calldata other_tokens) external returns (Amount[] memory) {
        // TODO: get amounts for trading eth_amount -> token_a (token_a_amount_token_from_eth)
        // TODO: get amounts for trading token_a_amount_from_eth -> ETH (=token_a_amount_eth_from_token)

        uint num_amounts = (1 + other_tokens.length) * 2;

        Amount[] memory amounts = new Amount[](num_amounts);

        for (uint i = 0; i < other_tokens.length; i++) {
            address token_b = other_tokens[i];

            if (token_a == token_b) {
                continue;
            }

            if (token_a > token_b) {
                // these orders will be created when we call get_prices for token_b
                continue;
            }

            // TODO: get amounts for trading token_a -> token_b
            // TODO: get amounts for trading token_b -> token_a
        }

        return amounts;
    }
}
