/**
 * Split a trade across multiple other exchange actions.
 * we will probably want a more advanced contract that can enable/disable different exchanges to keep gas costs down.
 */
pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IERC20} from "contracts/UniversalERC20.sol";
import {IOneSplit} from "interfaces/onesplit/IOneSplit.sol";

// TODO: do we want auth on this with setters? i think no. i think we should just have a simple contract with a constructor. if we need changes, we can deploy a new contract. less methods is less attack surface
contract OneSplitOffchainAction is AbstractERC20Exchange {

    // https://github.com/CryptoManiacsZone/1split/blob/master/contracts/IOneSplit.sol
    IOneSplit _one_split;

    address constant internal ETH_ON_ONESPLIT = address(0x0);

    constructor(address one_split) public {
        _one_split = IOneSplit(one_split);
    }

    // src_amount isn't necessarily the amount being traded. it is the amount used to determine the distribution
    function encodeExtraData(address src_token, address dest_token, uint src_amount, uint dest_min_tokens, uint256 parts)
        external view
        returns (uint256, bytes memory)
    {
        require(dest_min_tokens > 0, "OneSplitOffchainAction.encodeExtraData: dest_min_tokens must be > 0");

        // TODO: think about this more. i think using distribution makes disabling unused exchanges not actually do anything.
        // TODO: maybe take this as a function arg
        uint256 disable_flags = allEnabled();

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
        _one_split.swap{value: src_balance}(IERC20(ETH_ON_ONESPLIT), IERC20(dest_token), src_balance, dest_min_tokens, distribution, disable_flags);

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
        IERC20(src_token).approve(address(_one_split), src_balance);

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
        IERC20(src_token).approve(address(_one_split), src_balance);

        // do the actual swap
        // TODO: do we need to pass dest_min_tokens since we did the check above? maybe just pass 0 or 1
        _one_split.swap(IERC20(src_token), IERC20(ETH_ON_ONESPLIT), src_balance, dest_min_tokens, distribution, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = address(this).balance;
        require(dest_balance >= dest_min_tokens, "OneSplitOffchainAction._tradeTokenToEther: LOW_DEST_BALANCE");

        // TODO: don't use transfer. use call instead. and search for anywhere else we use transfer, too
        payable(to).transfer(dest_balance);
    }

    struct Amount {
        uint256 maker_wei;
        address maker_address;
        uint256 taker_wei;
        address taker_address;
        uint256 parts;
        uint256[] distribution;
    }

    function allEnabled() internal view returns (uint256 disable_flags) {
        disable_flags = 0;

        // TODO: these cause reverts if the assets aren't compatible
        // disable_flags += _one_split.FLAG_ENABLE_MULTI_PATH_ETH();
        // disable_flags += _one_split.FLAG_ENABLE_MULTI_PATH_DAI();
        // disable_flags += _one_split.FLAG_ENABLE_MULTI_PATH_USDC();
        // disable_flags += _one_split.FLAG_ENABLE_UNISWAP_COMPOUND();
        // disable_flags += _one_split.FLAG_ENABLE_UNISWAP_CHAI();
        // disable_flags += _one_split.FLAG_ENABLE_UNISWAP_AAVE();
    }

    function getExpectedReturnForAmount(Amount memory a, uint disable_flags) internal view returns (Amount memory) {
        (uint maker_wei, uint[] memory distribution) = _one_split.getExpectedReturn(
            IERC20(a.maker_address),
            IERC20(a.taker_address),
            a.taker_wei,
            a.parts,
            disable_flags
        );

        a.maker_wei = maker_wei;
        a.distribution = distribution;

        return a;
    }

    // TODO: this is going to use a LOT of gas. theres still a gas limit, even on eth_call. we might have to smart about chunking this up
    function getAmounts(address token_a, uint256 eth_amount, address[] calldata other_tokens, uint256 parts) external returns (uint disable_flags, Amount[] memory) {
        disable_flags = allEnabled();  // TODO: we might have to fetch this for each asset, but i think this is will work

        uint num_amounts = (1 + other_tokens.length) * 2;

        Amount[] memory amounts = new Amount[](num_amounts);

        // get amounts for trading eth_amount -> token_a (token_a_amount_token_from_eth)
        amounts[0].maker_address = token_a;
        amounts[0].taker_wei = eth_amount;
        amounts[0].taker_address = ETH_ON_ONESPLIT;
        amounts[0].parts = parts;
        amounts[0] = getExpectedReturnForAmount(amounts[0], disable_flags);

        // get amounts for trading token_a_amount_from_eth -> ETH (=token_a_amount_eth_from_token)
        // TODO: i'd actually prefer for this to take the maker_amount. then it would actually eth_amount tokens purchased instead of some slipped amount
        amounts[1].maker_address = ETH_ON_ONESPLIT;
        amounts[1].taker_wei = amounts[0].maker_wei;
        amounts[1].taker_address = token_a;
        amounts[1].parts = parts;
        amounts[1] = getExpectedReturnForAmount(amounts[1], disable_flags);

        uint next_amount_id = 2;

        for (uint i = 0; i < other_tokens.length; i++) {
            address token_b = other_tokens[i];

            if (token_a == token_b) {
                continue;
            }

            if (token_a > token_b) {
                // orders will be created when we call get_prices for token_b
                continue;
            }

            // get amounts for trading token_a -> token_b
            // use the same amounts that we used in our ETH trades to keep these all around the same value
            amounts[next_amount_id].maker_address = token_b;
            amounts[next_amount_id].taker_wei = amounts[0].maker_wei;
            amounts[next_amount_id].taker_address = token_a;
            amounts[next_amount_id].parts = parts;
            amounts[next_amount_id] = getExpectedReturnForAmount(amounts[next_amount_id], disable_flags);

            next_amount_id++;
            if (next_amount_id > num_amounts) {
                revert("miscalculated num_amounts");
            }

            // get amounts for trading token_b -> token_a
            amounts[next_amount_id].maker_address = token_a;
            amounts[next_amount_id].taker_wei = amounts[next_amount_id - 1].maker_wei;
            amounts[next_amount_id].taker_address = token_b;
            amounts[next_amount_id].parts = parts;
            amounts[next_amount_id] = getExpectedReturnForAmount(amounts[next_amount_id], disable_flags);

            next_amount_id++;
            if (next_amount_id > num_amounts) {
                revert("miscalculated num_amounts");
            }
        }

        return (disable_flags, amounts);
    }
}

