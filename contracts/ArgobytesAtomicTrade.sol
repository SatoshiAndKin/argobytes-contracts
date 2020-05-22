// SPDX-License-Identifier: LGPL-3.0-or-later
// Argobytes is Satoshi & Kin's smart contract for arbitrage trading.
// Uses flash loans so that we have near infinite liquidity.
// Uses gas token so that we pay less in miner fees.
// TODO: use address payable once ethabi works with it
// ABIEncodeV2 is not yet supported by rust's ethabi, so be careful how you use it. don't expose new encodings in function args or returns
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {SafeMath} from "@openzeppelin/math/SafeMath.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {IInvokable} from "interfaces/kollateral/IInvokable.sol";
import {IInvoker} from "interfaces/kollateral/IInvoker.sol";
import {KollateralInvokable} from "interfaces/kollateral/KollateralInvokable.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";
import {IArgobytesAtomicTrade} from "interfaces/argobytes/IArgobytesAtomicTrade.sol";
import {Strings2} from "contracts/Strings2.sol";


contract ArgobytesAtomicTrade is AccessControl, IArgobytesAtomicTrade, KollateralInvokable {
    using SafeMath for uint;
    using Strings for uint;
    using Strings2 for address;
    using UniversalERC20 for IERC20;

    address internal constant ZERO_ADDRESS = address(0x0);
    address internal constant KOLLATERAL_ETH = address(0x0000000000000000000000000000000000000001);
    bytes32 public constant TRUSTED_TRADER_ROLE = keccak256("TRUSTED_TRADER_ROLE");

    // https://github.com/kollateral/kollateral/blob/master/lib/static/invoker.ts
    // they take a 6bps fee
    IInvoker public _kollateral_invoker;

    /**
     * @notice Initialize the contract. This should be called from a CREATE2 deploy helper!
     */
    constructor(address admin, address kollateral_invoker) public {
        // Grant an address the "default admin" role
        // it will be able to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, admin);

        // TODO: if we want this open, this should be an argument on every contract call. compare gas costs though. maybe just allow overriding
        _kollateral_invoker = IInvoker(kollateral_invoker);
    }

    function setKollateralInvoker(address kollateral_invoker) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not default admin");

        // TODO: emit an event

        _kollateral_invoker = IInvoker(kollateral_invoker);
    }

    // TODO: get rid of this. do encoding outside of the smart contract
    // this is here because I'm having trouble encoding these types in Rust
    function encodeActions(address payable[] memory targets, bytes[] memory targets_data) public pure returns (bytes memory encoded_data) {
        require(targets.length == targets_data.length, "ArgobytesAtomicTrade.encodeActions: lengths do not match");

        Action[] memory actions = new Action[](targets.length);

        for (uint i = 0; i < targets.length; i++) {
            actions[i] = Action(targets[i], targets_data[i]);
        }

        encoded_data = abi.encode(actions);
    }

    // // atomicTrade that you can call from an EOA. Just approve this contract to transfer first, then transfer as your first Action.
    // // be careful not to leave any tokens behind!
    // function openAtomicTrade(Action[] calldata actions) external payable override {
    //     // TODO: open this up once it has been audited
    //     require(hasRole(TRUSTED_TRADER_ROLE, msg.sender), "ArgobytesAtomicArbitrage.openAtomicTrade: Caller is not trusted");

    //     executeSolo(address(0), 0, actions);
    // }

    /**
     * @notice Trade `first_amount` `tokens[0]` and return profits to msg.sender. Does NOT revert if no profit
     */
    function atomicTrade(address[] calldata tokens, uint256 first_amount, bytes calldata encoded_actions)
        external payable override
    {
        // TODO: add deadline to prevent miners doing sneaky things by broadcasting transactions late
        // TODO: if we want to use GSN, we should use `_msgSender()` instead of msg.sender
        // TODO: open this up once it has been audited
        require(hasRole(TRUSTED_TRADER_ROLE, msg.sender), "ArgobytesAtomicArbitrage.atomicTrade: Caller is not trusted");

        require(tokens.length > 0, "ArgobytesAtomicArbitrage.atomicTrade: tokens.length must be > 0");
        require(first_amount > 0, "ArgobytesAtomicArbitrage.atomicTrade: first_amount must be > 0");

        uint256 starting_amount = IERC20(tokens[0]).universalBalanceOf(address(this));

        // https://docs.kollateral.co/implementation#passing-data-to-execute
        // we used to have our own borrowing code here, but we should instead use other people's open source work when possible
        if (starting_amount >= first_amount) {
            executeSolo(tokens[0], first_amount, encoded_actions);
        } else {
            // we don't actually make sure we profited here.
            // we do not have enough token to do this arbitrage ourselves. call kollateral for the remainder
            first_amount -= starting_amount;

            if (tokens[0] == ZERO_ADDRESS) {
                // use kollateral's address for ETH instead of the zero address we use
                _kollateral_invoker.invoke(address(this), encoded_actions, KOLLATERAL_ETH, first_amount);
            } else {
                _kollateral_invoker.invoke(address(this), encoded_actions, tokens[0], first_amount);
            }
            
            // kollateral ensures that we repaid our debts, but it doesn't require profit beyond that
            // this could still be benificial if we are a liquidity provider on kollateral, so we allow it
        }

        // this contract should now have some tokens in it
        // TODO: it is possible all tokens went to other addresses or to repay the loan. If the caller doesn't want that, they can revert

        // sweep any profits to another address (likely cold storage, but could be a fancy smart wallet, but please not a hot wallet!)
        // there might be leftovers from some of the trades so we sweep all tokens involved
        // TODO: move this to a sweep function?
        for (uint i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);

            // use univeralBalanceOf because one of these tokens might actually be ETH
            uint256 ending_amount = token.universalBalanceOf(address(this));

            if (ending_amount == 0) {
                // TODO: do we need this? is universalTransfer smart enough to do this for us?
                continue;
            }

            // we don't emit events ourselves because token transfers already do
            // ETH profits won't emit logs, but it is easy to check balance changes
            // TODO: we could take an address instead of sending back to msg.sender, but this works for our vault which is our main user for now
            token.universalTransfer(msg.sender, ending_amount);
        }
    }

    /**
      * @notice Entrypoint for Kollateral to execute arbitrary actions and then repay what was borrowed from Kollateral (plus a small fee).
      * @dev https://docs.kollateral.co/implementation#creating-your-invokable-smart-contract
      */
    function execute(bytes calldata encoded_actions) external override payable {
        // TODO: open this up once it has been audited
        require(currentSender() == address(this), "ArgobytesAtomicTrade.execute: Original sender is not this contract");

        // TODO: can we get a revert message if the decode fails?
        (Action[] memory actions) = abi.decode(encoded_actions, (Action[]));

        // we could allow 0 actions, but why would we ever want to pay a fee to do nothing?
        require(actions.length > 0, "ArgobytesAtomicArbitrage.execute: there must be at least one action");

        uint256 action_value = 0;
        bool is_current_token_ether = isCurrentTokenEther();
        // TODO! IMPORTANT! THIS HAS A UNIQUE ETH ADDRESS!
        IERC20 borrowed_token = IERC20(currentTokenAddress());

        if (is_current_token_ether) {
            // this amount gets sent with the call 
            action_value = address(this).balance;
        } else {
            // transer tokens to the first action

            // we can't use currentTokenAmount because we might have had a balance before borrowing anything!
            // uint256 borrowed_amount = currentTokenAmount();
            // we don't need universalBalanceOf because we know this isn't ETH
            uint256 borrowed_amount = borrowed_token.balanceOf(address(this));

            borrowed_token.transfer(actions[0].target, borrowed_amount);
        }

        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        // all that we care about is that we can repay our debts
        // this doesn't have to be an arbitrage trade
        for (uint256 i = 0; i < actions.length; i++) {
            address action_address = actions[i].target;

            // calls to this aren't expected, so lets just block them to be safe
            require(action_address != address(this), "ArgobytesAtomicArbitrage.execute: calls to self are not allowed");

            // IMPORTANT! An action contract could be designed that keeps profits for itself.
            // Preventing that will be very difficult. This is why other similar contracts take a fee.
            // TODO: make sure actions[i].contract_address is on an allow list

            // Generally, avoid using call
            // We need call here though because we want to call arbitrary contracts with arbitrary arguments
            // ignore a success' return data. using it would limit compatability
            // on error, call_returned should have the revert message
            // solium-disable-next-line security/no-low-level-calls
            (bool success, bytes memory call_returned) = action_address.call{value: action_value}(actions[i].data);

            if (!success) {
                string memory err = string(abi.encodePacked("ArgobytesAtomicTrade.execute: on call #", i.toString()," to ", action_address.toString(), " with ", action_value.toString(), " ETH failed: '", string(call_returned), "'"));
                revert(err);
            }

            // clear the action_value since we already sent it
            action_value = 0;
        }

        // TODO: get rid of this when done debugging?
        uint256 repay_amount = currentRepaymentAmount();

        if (is_current_token_ether) {
            uint256 balance = address(this).balance;

            if (balance == 0) {
                revert("ArgobytesAtomicTrade.execute: No ETH balance was returned by the last action");
            }

            require(balance >= repay_amount, "ArgobytesAtomicTrade.execute: Not enough ETH balance to repay kollateral");
        } else {
            uint256 balance = borrowed_token.balanceOf(address(this));

            if (balance == 0) {
                revert("ArgobytesAtomicTrade.execute: No token balance was returned by the last action");
            }

            require(balance >= repay_amount, "ArgobytesAtomicTrade.execute: Not enough token balance to repay kollateral");
        }

        repay();
    }

    /**
      * @notice Execute arbitrary actions when we have enough funds without borrowing from anywhere.
      */
    // TODO: private or internal?
    function executeSolo(address first_token, uint256 first_amount, bytes memory encoded_actions) private {
        // TODO: would be nice to have a revert message here if this fails to decode
        // TODO: accept Action[] memory actions directly?
        (Action[] memory actions) = abi.decode(encoded_actions, (Action[]));

        // we could allow 0 actions, but why would we ever want that?
        require(actions.length > 0, "ArgobytesAtomicArbitrage.executeSolo: there must be at least one action");

        // debugging
        uint256 first_token_balance = IERC20(first_token).universalBalanceOf(address(this));
        require(first_token_balance >= first_amount, "ArgobytesAtomicArbitrage.executeSolo: not enough token");

        IERC20(first_token).universalTransfer(actions[0].target, first_amount);

        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        // this does NOT have to end with a profitable arbitrage. If you want that, 
        for (uint i = 0; i < actions.length; i++) {
            address action_address = actions[i].target;

            // calls to this aren't expected, so lets just block them to be safe
            require(action_address != address(this), "ArgobytesAtomicArbitrage.executeSolo: calls to self are not allowed");

            // IMPORTANT! An action contract could be designed that keeps profits for itself.
            // Preventing that will be very difficult. This is why other similar contracts take a fee.

            // Generally, avoid using call
            // We need call here though because we want to call arbitrary contracts with arbitrary arguments
            // ignore a success' return data. using it would limit compatability
            // on error, call_returned should have the revert message
            // solium-disable-next-line security/no-low-level-calls
            (bool success, bytes memory call_returned) = action_address.call(actions[i].data);

            if (!success) {
                // TODO: process call_returned. we need to cut the first 4 bytes off and convert to a string

                string memory err = string(abi.encodePacked("ArgobytesAtomicTrade.executeSolo: on call #", i.toString()," to ", action_address.toString(), " failed: '", string(call_returned), "'"));
                revert(err);
            }
        }
    }
}
