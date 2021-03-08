// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
// Burns LiquidGasToken (or compatible contracts)
// TODO: rewrite this to use the FlashLoan EIP
// TODO: rewrite this to be an ArgobytesClone
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@OpenZeppelin/token/ERC20/SafeERC20.sol";

import {ArgobytesClone} from "contracts/abstract/ArgobytesClone.sol";
import {ArgobytesMulticall} from "contracts/ArgobytesMulticall.sol";
import {IDyDxCallee} from "contracts/external/dydx/IDyDxCallee.sol";
import {DyDxTypes, IDyDxSoloMargin} from "contracts/external/dydx/IDyDxSoloMargin.sol";

interface IArgobytesTrader {
    struct Borrow {
        uint256 amount;
        IERC20 token;
        address dest;
    }

    function atomicArbitrage(
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) external payable;

    function atomicTrade(
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) external payable;

    function dydxFlashArbitrage(
        IDyDxSoloMargin soloMargin,
        uint256 borrow_id,
        IERC20 borrow_token,
        uint256 borrow_amount,
        address argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) external payable;
}

// TODO: this isn't right. this works for the owner account, but needs more thought for authenticating a bot
// TODO: maybe have a function approvedAtomicAbitrage that calls transferFrom. and another that that assumes its used from the owner of the funnds with delegatecall
contract ArgobytesTrader is IArgobytesTrader, ArgobytesClone {
    using SafeERC20 for IERC20;

    bool _pending_flashloan = false;

    IDyDxSoloMargin constant DYDX_SOLO_MARGIN = IDyDxSoloMargin(
        0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e
    );

    address constant WETH9 = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // TODO: return gas tokens freed?
    function atomicArbitrage(
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) external override payable {
        uint256[] memory start_balances = new uint256[](borrows.length);

        // record starting token balances to check for increases
        // transfer tokens from msg.sender to arbitrary destinations
        // TODO: what about ETH balances?
        for (uint256 i = 0; i < borrows.length; i++) {
            start_balances[i] = borrows[i].token.balanceOf(borrow_from);

            // TODO: think about this and approvals more
            // TODO: do we want this address(0) check? i think it will be helpful in the case where the clone is holding the coins
            if (borrow_from == address(0)) {
                borrows[i].token.safeTransfer(
                    borrows[i].dest,
                    borrows[i].amount
                );
            } else {
                borrows[i].token.safeTransferFrom(
                    borrow_from,
                    borrows[i].dest,
                    borrows[i].amount
                );
            }
        }

        // we call this as a seperate contract because we don't want any sneaky transferFroms
        // TODO: make sure this actually does what we want by doing a "transferFrom" in the actions!
        // this contract (or the actions) MUST return all borrowed tokens to msg.sender
        // TODO: pass ETH along? this might be helpful for exchanges like 0x. maybe better to borrow WETH9 for the action
        // TODO: msg.value or address(this).balance?!
        argobytes_multicall.callActions{value: msg.value}(actions);

        // make sure the source's balances did not decrease
        // we allow it to be equal because it's possible that we got our profits on another token or from LP fees
        // TODO: we do this in the opposite order that we started in. does that matter?
        for (uint256 i = borrows.length; i > 0; i--) {
            uint256 j = i - 1;

            // return any tokens that the actions didn't already return
            uint256 this_balance = borrows[j].token.balanceOf(address(this));

            borrows[j].token.safeTransfer(borrow_from, this_balance);

            uint256 end_balance = borrows[j].token.balanceOf(borrow_from);

            // make sure the balance increased
            require(
                end_balance >= start_balances[j],
                "ArgobytesTrader: BAD_ARBITRAGE"
            );
        }

        // TODO: refund excess ETH?
    }

    // TODO: return gas tokens freed?
    /**
     * @notice Transfer `first_amount` `tokens[0]`, call some functions, and return tokens to msg.sender.
     * @notice You'll need to call this from another smart contract that has authentication.
     */
    function atomicTrade(
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) external override payable auth {
        // transfer tokens from msg.sender to arbitrary destinations
        // this is dangerous! be careful with this!
        for (uint256 i = 0; i < borrows.length; i++) {
            // TODO: think about this and approvals more
            if (borrow_from == address(0)) {
                borrows[i].token.safeTransfer(
                    borrows[i].dest,
                    borrows[i].amount
                );
            } else {
                borrows[i].token.safeTransferFrom(
                    borrow_from,
                    borrows[i].dest,
                    borrows[i].amount
                );
            }
        }

        // TODO: msg.value or address(this).balance?!
        // we call a seperate contract because we don't want any sneaky transferFroms
        argobytes_multicall.callActions{value: msg.value}(actions);

        // TODO: refund excess ETH?
    }

    /* optional safety check for the end of your `atomicTrade` actions
    */
    function checkERC20Balance(IERC20 token, address who, uint256 min_balance) public {
        require(token.balanceOf(who) >= min_balance, "low balance");
    }

    /* optional safety check for the end of your `atomicTrade` actions
    */
    function checkBalance(address who, uint256 min_balance) public {
        require(who.balance >= min_balance, "low balance");
    }

    // flash loan from dydx
    // TODO: return gas tokens freed?
    function dydxFlashArbitrage(
        IDyDxSoloMargin soloMargin,
        uint256 borrow_id,
        IERC20 borrow_token,
        uint256 borrow_amount,
        address argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) external override payable auth {
        // TODO: move this dydx stuff to a helper
        // we want to give coins to argobytes actor
        // TODO: why is the linter adding extra line breaks?!
        DyDxTypes.AccountInfo[] memory accountInfos = new DyDxTypes.AccountInfo[](1);
        
        abi.encode(actions)

        // we could check for actual profit here, but i don't think its necessary
    }
}
