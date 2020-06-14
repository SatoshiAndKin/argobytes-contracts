// SPDX-License-Identifier: LGPL-3.0-or-later
/*
 * There are multitudes of possible contracts for SoloArbitrage. AbstractExchange is for interfacing with ERC20.
 *
 * These contracts should also be written in a way that they can work with any flash lender
 *
 * Rewrite this to use UniversalERC20? I'm not sure its worth it. this is pretty easy to follow.
 */
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {Address} from "@openzeppelin/utils/Address.sol";
import {SafeMath} from "@openzeppelin/math/SafeMath.sol";

import {IERC20, UniversalERC20, SafeERC20} from "contracts/UniversalERC20.sol";

contract AbstractERC20Modifiers {
    using Address for address;
    using SafeERC20 for IERC20;
    using UniversalERC20 for IERC20;

    address constant ADDRESS_ZERO = address(0);

    // this contract must be able to receive ether if it is expected to return it
    receive() external payable {}

    /// @dev after the function, send any remaining ether back to msg.sender
    modifier returnLeftoverEther() {
        _;

        uint256 balance = address(this).balance;

        if (balance > 0) {
            Address.sendValue(msg.sender, balance);
        }
    }

    /// @dev after the function, send any remaining tokens to an address
    modifier returnLeftoverToken(address token, address approved) {
        _;

        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance > 0) {
            IERC20(token).safeTransfer(msg.sender, balance);

            if (approved != ADDRESS_ZERO) {
                // clear the approval since we didn't trade everything
                IERC20(token).safeApprove(approved, 0);
            }
        }
    }

    /// @dev after the function, send any remaining ether or tokens to an address
    modifier returnLeftoverUniversal(address token, address approved) {
        _;

        uint256 balance = IERC20(token).universalBalanceOf(address(this));

        if (balance > 0) {
            IERC20(token).universalTransfer(msg.sender, balance);

            if (approved != ADDRESS_ZERO) {
                // clear the approval since we didn't trade everything
                IERC20(token).safeApprove(approved, 0);
            }
        }
    }
}

abstract contract AbstractERC20Exchange is AbstractERC20Modifiers {
    struct Amount {
        address maker_token;
        uint256 maker_wei;
        address taker_token;
        uint256 taker_wei;
        bytes4 selector;
        bytes trade_extra_data;
        bytes exchange_data;
        string error;
    }

    function _getAmounts(
        address token_a,
        uint256 token_a_amount,
        address token_b,
        bytes memory extra_data
    ) internal view returns (Amount[] memory) {
        require(token_a != token_b, "token_a should != token_b");

        Amount[] memory amounts = new Amount[](2);

        // we can't use try/catch with internal functions, so we use staticcall instead

            string memory newAmountSignature
         = "newAmount(address,uint256,address,bytes)";

        // get amounts for trading token_a -> token_b
        // use the same amounts that we used in our ETH trades to keep these all around the same value
        (bool success, bytes memory returnData) = address(this).staticcall(
            abi.encodeWithSignature(
                newAmountSignature,
                token_b,
                token_a_amount,
                token_a,
                extra_data
            )
        );

        if (success) {
            amounts[0] = abi.decode(returnData, (Amount));

            // if we have amounts for the first trade, get amounts for trading token_b -> token_a
            if (amounts[0].maker_wei > 0) {
                (success, returnData) = address(this).staticcall(
                    abi.encodeWithSignature(
                        newAmountSignature,
                        token_a,
                        amounts[0].maker_wei,
                        token_b,
                        extra_data
                    )
                );
                if (success) {
                    amounts[1] = abi.decode(returnData, (Amount));
                }
            }
        }

        return amounts;
    }

    function newAmount(
        address maker_token,
        uint256 taker_wei,
        address taker_token,
        bytes memory extra_data
    ) public virtual view returns (Amount memory);

    function newPartialAmount(
        address maker_token,
        uint256 taker_wei,
        address taker_token
    ) internal pure returns (Amount memory) {
        Amount memory a = Amount({
            maker_token: maker_token,
            maker_wei: 0,
            taker_token: taker_token,
            taker_wei: taker_wei,
            selector: "",
            trade_extra_data: "",
            exchange_data: "",
            error: ""
        });

        // missing maker_wei, selector, trade_extra_data, exchange_data! you need to set these (or error) in your `newAmount`

        return a;
    }
}

// abstract contract AbstractERC20Exchange is AbstractERC20Amounts {

//     // TODO: i think we should get rid of these generic functions. most every function ignores at least one of the arguments. this should make cleaner contracts and not just be considered gas golfing
//     // these functions require that address(this) has an ether/token balance.
//     // these functions might have some leftover ETH or src_token in them after they finish, so be sure to use the return modifiers on whatever calls these
//     // TODO: decide on best order for the arguments
//     // TODO: _tradeUniversal? that won't be as gas efficient
//     function _tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;
//     function _tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;
//     function _tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;

//     function tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
//         external
//         payable
//         returnLeftoverEther(msg.sender)
//     {
//         if (to == ADDRESS_ZERO) {
//             to = msg.sender;
//         }

//         _tradeEtherToToken(to, dest_token, dest_min_tokens, dest_max_tokens, extra_data);
//     }

//     function tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
//         external
//         returnLeftoverToken(msg.sender, src_token)
//     {
//         if (to == ADDRESS_ZERO) {
//             to = msg.sender;
//         }

//         _tradeTokenToToken(to, src_token, dest_token, dest_min_tokens, dest_max_tokens, extra_data);
//     }

//     function tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
//         external
//         returnLeftoverToken(msg.sender, src_token)
//     {
//         if (to == ADDRESS_ZERO) {
//             to = msg.sender;
//         }

//         _tradeTokenToEther(to, src_token, dest_min_tokens, dest_max_tokens, extra_data);
//     }
// }
