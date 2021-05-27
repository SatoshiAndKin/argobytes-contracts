// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
// Burns LiquidGasToken (or compatible contracts)
// TODO: finish ArgobytesProxy refactor
// TODO: rewrite this to use the FlashLoan EIP instead of dydx. this allows lots more tokens
pragma solidity 0.8.4;

import {IERC20, SafeERC20} from "@OpenZeppelin/token/ERC20/utils/SafeERC20.sol";

import {ArgobytesAuth} from "contracts/abstract/ArgobytesAuth.sol";
import {ArgobytesMulticall} from "contracts/ArgobytesMulticall.sol";

contract ArgobytesTrader {
    // TODO: use this event
    event SetArgobytesMulticall(address indexed old_addr, address indexed new_addr);

    struct Borrow {
        uint256 amount;
        IERC20 token;
        address dest;
    }

    // diamond storage
    // TODO: use this
    struct ArgobytesTraderStorage {
        mapping(ArgobytesMulticall => bool) approved_argobytes_multicalls;
    }

    bytes32 constant ARGOBYTES_TRADER_STORAGE = keccak256("argobytes.storage.ArgobytesTrader");

    function argobytesTraderStorage() internal pure returns (ArgobytesTraderStorage storage s) {
        bytes32 position = ARGOBYTES_TRADER_STORAGE;
        assembly {
            s.slot := position
        }
    }

    /**
    * @dev ArgobytesProxy delegatecall actions can use this, but only safely from the owner
    * @notice Make atomic arbitrage trades
    */
    function atomicArbitrage(
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) public payable {
        uint256[] memory start_balances = new uint256[](borrows.length);

        // record starting token balances to check for increases
        // transfer tokens from msg.sender to arbitrary destinations
        // TODO: what about ETH balances?
        for (uint256 i = 0; i < borrows.length; i++) {
            start_balances[i] = borrows[i].token.balanceOf(borrow_from);

            // TODO: think about this and approvals more
            // TODO: do we want this address(0) check? i think it will be helpful in the case where the clone is holding the coins
            if (borrow_from == address(0)) {
                SafeERC20.safeTransfer(
                    borrows[i].token,
                    borrows[i].dest,
                    borrows[i].amount
                );
            } else {
                SafeERC20.safeTransferFrom(
                    borrows[i].token,
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
        // TODO: limit argobytes_multicall to a known mapping of contracts?
        argobytes_multicall.callActions{value: msg.value}(actions);

        // make sure the source's balances did not decrease
        // we allow it to be equal because it's possible that we got our profits on another token or from LP fees
        // TODO: we do this in the opposite order that we started in. does that matter?
        for (uint256 i = borrows.length; i > 0; i--) {
            uint256 j = i - 1;

            // return any tokens that the actions didn't already return
            uint256 this_balance = borrows[j].token.balanceOf(address(this));

            SafeERC20.safeTransfer(borrows[j].token, borrow_from, this_balance);

            uint256 end_balance = borrows[j].token.balanceOf(borrow_from);

            // make sure the balance increased
            require(
                end_balance >= start_balances[j],
                "ArgobytesTrader: BAD_ARBITRAGE"
            );
        }

        // TODO: refund excess ETH?
    }

    /**
     * @notice Transfer `first_amount` `tokens[0]`, call some functions, and return tokens to msg.sender.
     * @notice this might as well be called `function rugpull` with the transfers for anything. be careful with approvals here!
     * @notice You'll need to call this from another smart contract that has authentication!
     * @dev Dangerous ArgobytesProxy execute target
     */
    function atomicTrade(
        address withdraw_from,
        Borrow[] calldata withdraws,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) external payable {
        // transfer tokens from msg.sender to arbitrary destinations
        // this is dangerous! be careful with this!
        for (uint256 i = 0; i < withdraws.length; i++) {
            // TODO: think about this and approvals more
            if (withdraw_from == address(0)) {
                SafeERC20.safeTransfer(
                    withdraws[i].token,
                    withdraws[i].dest,
                    withdraws[i].amount
                );
            } else {
                SafeERC20.safeTransferFrom(
                    withdraws[i].token,
                    withdraw_from,
                    withdraws[i].dest,
                    withdraws[i].amount
                );
            }
        }

        // if you want to ensure that there was a gain in some token, add a requireERC20Balance or requireBalance action
        argobytes_multicall.callActions{value: msg.value}(actions);

        // TODO: refund excess ETH?
    }

    /// @dev safety check for the end of your atomicTrade or atomicArbitrage actions
    function requireERC20Balance(IERC20 token, address who, uint256 min_balance) public {
        require(token.balanceOf(who) >= min_balance, "ArgobytesTrader !balance");
    }

    /// @dev safety check for the end of your atomicTrade or atomicArbitrage actions
    function requireBalance(address who, uint256 min_balance) public {
        require(who.balance >= min_balance, "ArgobytesTrader !balance");
    }

    /**
     * @dev Like atomicArbitrage, but makes sure that `argobytes_multicall` is an approved contract.
     *
     * This should be safe to approve bots to use. At least thats the plan. Need an audit.
     */
    function safeAtomicArbitrage(
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) public payable {
        // TODO: make sure this multicall contract is approved
        require(false, "ArgobytesTrader.safeAtomicArbitrage !argobytes_multicall");

        atomicArbitrage(
            borrow_from,
            borrows,
            argobytes_multicall,
            actions
        );
    }
}
