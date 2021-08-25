pragma solidity 0.8.7;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IERC20} from "contracts/library/UniversalERC20.sol";
import {IOneSplit} from "interfaces/onesplit/IOneSplit.sol";

contract OneSplitOnchainAction is AbstractERC20Exchange {
    IOneSplit _one_split;

    constructor(address one_split) public {
        _one_split = IOneSplit(one_split);
    }

    // https://github.com/CryptoManiacsZone/1split/blob/master/contracts/IOneSplit.sol
    function encodeExtraData(uint256 parts, uint256 disable_flags)
        external
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encode(parts, disable_flags);
    }

    // TODO: helper here that sets allowances and then transfers? i think IUniswapExchange might already have all the methods we need though
    function _tradeEtherToToken(
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        uint256, /* dest_max_tokens */
        bytes memory extra_data
    ) internal override {
        (uint256 parts, uint256 disable_flags) = abi.decode(
            extra_data,
            (uint256, uint256)
        );

        uint256 src_balance = address(this).balance;
        require(
            src_balance > 0,
            "OneSplitAction._tradeEtherToToken: NO_ETH_BALANCE"
        );

        // no approvals are necessary since we are using ETH

        // calculate the amounts
        // TODO: this is MUCH cheaper to do off chain, but then we don't get the dynamic routing
        // TODO: i think what we will do is disable all but the top 3 exchanges
        (uint256 return_amount, uint256[] memory distribution) = _one_split
            .getExpectedReturn(
            IERC20(ADDRESS_ZERO),
            IERC20(dest_token),
            src_balance,
            parts,
            disable_flags
        );

        require(
            return_amount > dest_min_tokens,
            "OneSplitAction._tradeEtherToToken: LOW_EXPECTED_RETURN"
        );

        // do the actual swap (and send the ETH along as value)
        _one_split.swap{value: src_balance}(
            IERC20(ADDRESS_ZERO),
            IERC20(dest_token),
            src_balance,
            dest_min_tokens,
            distribution,
            disable_flags
        );

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(
            dest_balance >= dest_min_tokens,
            "OneSplitAction._tradeEtherToToken: LOW_DEST_BALANCE"
        );

        IERC20(dest_token).safeTransfer(to, dest_balance);
    }

    function _tradeTokenToToken(
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        uint256, /* dest_max_tokens */
        bytes memory extra_data
    ) internal override {
        (uint256 parts, uint256 disable_flags) = abi.decode(
            extra_data,
            (uint256, uint256)
        );

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(
            src_balance > 0,
            "OneSplitAction._tradeTokenToToken: NO_SRC_BALANCE"
        );

        IERC20(src_token).safeApprove(address(_one_split), src_balance);

        // calculate the amounts
        // TODO: this is MUCH cheaper to do off chain, but then we don't get the dynamic routing
        // TODO: i think what we will do is disable all but the top 3 exchanges
        (uint256 return_amount, uint256[] memory distribution) = _one_split
            .getExpectedReturn(
            IERC20(src_token),
            IERC20(dest_token),
            src_balance,
            parts,
            disable_flags
        );

        require(
            return_amount > dest_min_tokens,
            "OneSplitAction._tradeTokenToToken: LOW_EXPECTED_RETURN"
        );

        // do the actual swap
        _one_split.swap(
            IERC20(src_token),
            IERC20(dest_token),
            src_balance,
            dest_min_tokens,
            distribution,
            disable_flags
        );

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(
            dest_balance >= dest_min_tokens,
            "OneSplitAction._tradeTokenToToken: LOW_DEST_BALANCE"
        );

        IERC20(dest_token).safeTransfer(to, dest_balance);
    }

    function _tradeTokenToEther(
        address payable to,
        address src_token,
        uint256 dest_min_tokens,
        uint256, /* dest_max_tokens */
        bytes memory extra_data
    ) internal override {
        (uint256 parts, uint256 disable_flags) = abi.decode(
            extra_data,
            (uint256, uint256)
        );

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(
            src_balance > 0,
            "OneSplitAction._tradeTokenToEther: NO_SRC_BALANCE"
        );

        IERC20(src_token).safeApprove(address(_one_split), src_balance);

        // calculate the amounts
        // TODO: this is MUCH cheaper to do off chain, but then we don't get the dynamic routing
        // TODO: i think what we will do is disable all but the top 3 exchanges
        (uint256 return_amount, uint256[] memory distribution) = _one_split
            .getExpectedReturn(
            IERC20(src_token),
            IERC20(ADDRESS_ZERO),
            src_balance,
            parts,
            disable_flags
        );

        require(
            return_amount > dest_min_tokens,
            "OneSplitAction.tradeTokenToEther: LOW_EXPECTED_RETURN"
        );

        // do the actual swap
        // TODO: do we need to pass dest_min_tokens since we did the check above? maybe just pass 0 or 1
        _one_split.swap(
            IERC20(src_token),
            IERC20(ADDRESS_ZERO),
            src_balance,
            dest_min_tokens,
            distribution,
            disable_flags
        );

        // forward the tokens that we bought
        uint256 dest_balance = address(this).balance;
        require(
            dest_balance >= dest_min_tokens,
            "OneSplitAction.tradeTokenToEther: LOW_DEST_BALANCE"
        );

        (bool success, ) = to.call{value: dest_balance}();
        require(
            success,
            "OneSplitAction.tradeTokenToEther: ETH_TRANSFER_FAILED"
        );
    }

    function getAmounts(
        address token_a,
        uint256 token_a_amount,
        address token_b,
        uint256 parts
    ) external view returns (Amount[] memory) {
        bytes memory extra_data = abi.encode(parts);

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(
        address maker_address,
        uint256 taker_wei,
        address taker_address,
        bytes memory extra_data
    ) public override view returns (Amount memory) {
        revert("wip");
    }
}
