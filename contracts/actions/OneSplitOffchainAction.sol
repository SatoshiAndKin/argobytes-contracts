pragma solidity 0.6.7;
pragma experimental ABIEncoderV2;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IERC20} from "contracts/UniversalERC20.sol";
import {IOneSplit} from "interfaces/onesplit/IOneSplit.sol";

// TODO: do we want auth on this with setters? i think no. i think we should just have a simple contract with a constructor. if we need changes, we can deploy a new contract. less methods is less attack surface
contract OneSplitOffchainAction is AbstractERC20Exchange {

    // https://github.com/CryptoManiacsZone/1split/blob/master/contracts/IOneSplit.sol
    IOneSplit _one_split;

    constructor(address one_split) public {
        _one_split = IOneSplit(one_split);
    }

    // call this function. do not include it in your actual transaction or the gas costs are excessive
    // src_amount isn't necessarily the amount being traded. it is the amount used to determine the distribution
    function encodeExtraData(address src_token, address dest_token, uint src_amount, uint dest_min_tokens, uint256 parts)
        external view
        returns (uint256, bytes memory)
    {
        require(dest_min_tokens > 0, "OneSplitOffchainAction.encodeExtraData: dest_min_tokens must be > 0");

        // TODO: think about this more. i think using distribution makes disabling unused exchanges not actually do anything.
        // TODO: maybe take this as a function arg
        uint256 disable_flags = allEnabled(src_token, dest_token);

        (uint256 expected_return, uint256[] memory distribution) = _one_split.getExpectedReturn(
            IERC20(src_token),
            IERC20(dest_token),
            src_amount,
            parts,
            disable_flags
        );

        require(expected_return > dest_min_tokens, "OneSplitOffchainAction.encodeExtraData: LOW_EXPECTED_RETURN");

        bytes memory encoded = abi.encode(distribution, disable_flags);

        return (expected_return, encoded);
    }

    function _tradeEtherToToken(
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 /* dest_max_tokens */,
        bytes memory extra_data
    ) internal override {
        (uint256[] memory distribution, uint256 disable_flags) = abi.decode(extra_data, (uint256[], uint256));

        uint256 src_balance = address(this).balance;
        require(src_balance > 0, "OneSplitOffchainAction._tradeEtherToToken: NO_ETH_BALANCE");

        // no approvals are necessary since we are using ETH

        // do the actual swap (and send the ETH along as value)
        _one_split.swap{value: src_balance}(IERC20(ZERO_ADDRESS), IERC20(dest_token), src_balance, dest_min_tokens, distribution, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(dest_balance >= dest_min_tokens, "OneSplitOffchainAction._tradeEtherToToken: LOW_DEST_BALANCE");

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
        (uint256[] memory distribution, uint256 disable_flags) = abi.decode(extra_data, (uint256[], uint256));

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(src_balance > 0, "OneSplitOffchainAction._tradeTokenToToken: NO_SRC_BALANCE");

        // approve tokens
        require(IERC20(src_token).approve(address(_one_split), src_balance), "OneSplitOffchainAction._tradeTokenToToken: FAILED_APPROVE");

        // do the actual swap
        _one_split.swap(IERC20(src_token), IERC20(dest_token), src_balance, dest_min_tokens, distribution, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(dest_balance >= dest_min_tokens, "OneSplitOffchainAction._tradeTokenToToken: LOW_DEST_BALANCE");

        IERC20(dest_token).transfer(to, dest_balance);
    }

    function _tradeTokenToEther(
        address to,
        address src_token,
        uint256 dest_min_tokens,
        uint256 /* dest_max_tokens */,
        bytes memory extra_data
    ) internal override {
        (uint256[] memory distribution, uint256 disable_flags) = abi.decode(extra_data, (uint256[], uint256));

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(src_balance > 0, "OneSplitOffchainAction._tradeTokenToEther: NO_SRC_BALANCE");

        // approve tokens
        require(IERC20(src_token).approve(address(_one_split), src_balance), "OneSplitOffchainAction._tradeTokenToEther: FAILED_APPROVE");

        // do the actual swap
        // TODO: do we need to pass dest_min_tokens since we did the check above? maybe just pass 0 or 1
        _one_split.swap(IERC20(src_token), IERC20(ZERO_ADDRESS), src_balance, dest_min_tokens, distribution, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = address(this).balance;
        require(dest_balance >= dest_min_tokens, "OneSplitOffchainAction._tradeTokenToEther: LOW_DEST_BALANCE");

        // TODO: don't use transfer. use call instead. and search for anywhere else we use transfer, too
        payable(to).transfer(dest_balance);
    }

    function allEnabled(address a, address b) internal view returns (uint256 disable_flags) {
        disable_flags = 0;

        // think about multi_path more. for now, it costs WAY too much gas.
        // we don't need multipath because we are already finding those paths with our arbitrage finding code
        // disable_flags += _one_split.FLAG_ENABLE_MULTI_PATH_ETH();
        // disable_flags += _one_split.FLAG_ENABLE_MULTI_PATH_DAI();
        // disable_flags += _one_split.FLAG_ENABLE_MULTI_PATH_USDC();

        // Works only when one of assets is ETH or FLAG_ENABLE_MULTI_PATH_ETH
        // TODO: investigate
        // disable_flags += _one_split.FLAG_ENABLE_UNISWAP_COMPOUND();

        // TODO: investigate
        // disable_flags += _one_split.FLAG_ENABLE_UNISWAP_AAVE();

        // Works only when ETH<>DAI or FLAG_ENABLE_MULTI_PATH_ETH
        // TODO: investigate
        // disable_flags += _one_split.FLAG_ENABLE_UNISWAP_CHAI();
    }

    function encodeAmountsExtraData(uint256 parts) external view returns (bytes memory) {
        return abi.encode(parts);
    }

    function getAmounts(address token_a, uint256 token_a_amount, address token_b, uint256 parts)
        external view
        returns (Amount[] memory)
    {
        bytes memory extra_data = abi.encode(parts);

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(address maker_token, uint taker_wei, address taker_token, bytes memory extra_data)
        public override view
        returns (Amount memory)
    {
        uint256 parts = abi.decode(extra_data, (uint256));

        Amount memory a = newPartialAmount(maker_token, taker_wei, taker_token);

        // TODO: would be cool to encode the complete calldata, but we can't be sure about the to address. we could default to 0x0
        (uint256 expected_return, bytes memory encoded) = this.encodeExtraData(a.taker_token, a.maker_token, a.taker_wei, 1, parts);

        a.maker_wei = expected_return;
        a.trade_extra_data = encoded;
        
        if (maker_token == ZERO_ADDRESS) {
            a.selector = this.tradeTokenToEther.selector;
        } else if (taker_token == ZERO_ADDRESS) {
            a.selector = this.tradeEtherToToken.selector;
        } else {
            a.selector = this.tradeTokenToToken.selector;
        }

        return a;
    }
}
