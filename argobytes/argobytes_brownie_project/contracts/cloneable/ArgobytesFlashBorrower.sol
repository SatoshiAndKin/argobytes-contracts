// SPDX-License-Identifier: MPL-2.0
/**
 * ArgobytesFlashBorrower is an extension to ArgobytesProxy that is also an IERC3156 Flash Loan Borrower.
 */
pragma solidity 0.8.4;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {IERC20} from "contracts/external/erc20/IERC20.sol";

import {ActionTypes} from "contracts/abstract/ActionTypes.sol";
import {BytesLib} from "contracts/library/BytesLib.sol";
import {IERC3156FlashBorrower} from "contracts/external/erc3156/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "contracts/external/erc3156/IERC3156FlashLender.sol";

import {ActionReverted, ArgobytesProxy, InvalidTarget} from "./ArgobytesProxy.sol";

error LenderDenied();
error Reentrancy();
error NoPendingLoan();
error InvalidLender();
error InvalidInitiator();

abstract contract ArgobytesFlashBorrowerEvents {
    event Lender(address indexed sender, address indexed lender, bool allowed);
}

contract ArgobytesFlashBorrower is ArgobytesProxy, ArgobytesFlashBorrowerEvents, IERC3156FlashBorrower {
    /// @dev diamond storage
    struct FlashBorrowerStorage {
        mapping(IERC3156FlashLender => bool) allowed_lenders;
        bool block_flashloan_callback;
        address pending_lender;
        Action pending_action;
        bytes pending_return;
    }

    /// @dev diamond storage
    bytes32 constant FLASH_BORROWER_POSITION = keccak256("argobytes.storage.FlashBorrower.lender");

    /// @dev diamond storage
    function flashBorrowerStorage() internal pure returns (FlashBorrowerStorage storage s) {
        bytes32 position = FLASH_BORROWER_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @dev in addition to allowing the lender, you must also allow the caller with ArgobytesAuth/ArgobytesAuthority
    function allowLender(IERC3156FlashLender lender) external auth(ActionTypes.Call.ADMIN) {
        FlashBorrowerStorage storage s = flashBorrowerStorage();

        s.allowed_lenders[lender] = true;

        emit Lender(msg.sender, address(lender), true);
    }

    function denyLender(IERC3156FlashLender lender) external auth(ActionTypes.Call.ADMIN) {
        FlashBorrowerStorage storage s = flashBorrowerStorage();

        delete s.allowed_lenders[lender];

        emit Lender(msg.sender, address(lender), false);
    }

    /// @dev Initiate a flash loan
    function flashBorrow(
        IERC3156FlashLender lender,
        address token,
        uint256 amount,
        Action calldata action
    ) public returns (bytes memory returned) {
        FlashBorrowerStorage storage s = flashBorrowerStorage();

        // check auth (owner is always allowed to use any lender and any action)
        if (msg.sender != owner()) {
            if (!s.allowed_lenders[lender]) revert LenderDenied();
            requireAuth(action.target, action.call_type, BytesLib.toBytes4(action.target_calldata));
        }

        if (s.block_flashloan_callback == false) {
            // TODO: do we need this check?
            revert Reentrancy();
        }

        // we could pass the calldata to the lender and have them pass it back, but that seems less safe
        // instead, use storage so that no one can change it
        s.block_flashloan_callback = false;
        s.pending_lender = address(lender);
        s.pending_action = action;

        // uint256 max_loan = lender.maxFlashLoan(token);

        // call the lender who will send us tokens and then call this.onFlashLoan
        // we don't give them any calldata because we keep our action in state
        // state is expensive, but it is also safest
        lender.flashLoan(this, token, amount, "");

        s.block_flashloan_callback = true;

        // copy the call's returned value to return it from this function
        returned = s.pending_return;

        // clear the pending values
        delete s.pending_lender;
        delete s.pending_action;
        delete s.pending_return;
    }

    /// @notice ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata /*data*/
    ) external override returns (bytes32) {
        FlashBorrowerStorage storage s = flashBorrowerStorage();

        // auth checks
        if (s.block_flashloan_callback) {
            // block_flashloan_callback works as authentication since only the flashBorrow function will set this to false
            revert NoPendingLoan();
        }
        if (msg.sender != s.pending_lender) {
            revert InvalidLender();
        }
        if (initiator != address(this)) {
            revert InvalidInitiator();
        }

        Action memory action = s.pending_action;

        if (!Address.isContract(action.target)) {
            revert InvalidTarget();
        }

        bool success;
        bytes memory action_returned;
        if (s.pending_action.call_type == ActionTypes.Call.DELEGATE) {
            (success, action_returned) = action.target.delegatecall(action.target_calldata);
        } else {
            // action.forward_value is ignored
            (success, action_returned) = action.target.call(action.target_calldata);
        }
        // TODO: what if call_type is ADMIN?

        if (!success) {
            revert ActionReverted(action.target, action.target_calldata, action_returned);
        }

        // since we can't return the call's return from here, we store it in state
        s.pending_return = action_returned;

        // approve paying back the loan
        IERC20(token).approve(s.pending_lender, amount + fee);

        // return their special response
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
