// SPDX-License-Identifier: LGPL-3.0-or-later
// use the flash loan EIP to receive tokens and then call arbitrary actions
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {ArgobytesClone} from "./ArgobytesClone.sol";

import {ArgobytesAuthTypes} from "contracts/abstract/ArgobytesAuth.sol";
import {Address2} from "contracts/library/Address2.sol";
import {Bytes2} from "contracts/library/Bytes2.sol";
import {IERC3156FlashBorrower} from "contracts/external/erc3156/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "contracts/external/erc3156/IERC3156FlashLender.sol";

abstract contract ArgobytesFlashBorrowerEvents {
    event Lender(address indexed sender, address indexed lender, bool allowed);
}

contract ArgobytesFlashBorrower is ArgobytesClone, ArgobytesFlashBorrowerEvents, IERC3156FlashBorrower {

    /// @dev diamond storage
    bytes32 constant FLASH_BORROWER_POSITION = keccak256("argobytes.storage.FlashBorrower.lender");

    /// @dev diamond storage
    struct FlashBorrowerStorage {
        mapping(IERC3156FlashLender => bool) allowed_lenders;
        bool pending_flashloan;
        address pending_lender;
        Action pending_action;
        bytes pending_return;
    }

    /// @dev diamond storage
    function flashBorrowerStorage() internal pure returns (FlashBorrowerStorage storage s) {
        bytes32 position = FLASH_BORROWER_POSITION;
        assembly {
            s.slot := position
        }
    }

    // TODO: gas golf this
    function allowLender(IERC3156FlashLender lender) external auth(ArgobytesAuthTypes.Call.ADMIN) {
        FlashBorrowerStorage storage s = flashBorrowerStorage();

        s.allowed_lenders[lender] = true;

        emit Lender(msg.sender, address(lender), true);
    }

    function denyLender(IERC3156FlashLender lender) external auth(ArgobytesAuthTypes.Call.ADMIN) {
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
            requireAuth(action.target, action.call_type, Bytes2.toBytes4(action.target_calldata));
            require(
                s.allowed_lenders[lender],
                "FlashBorrower.flashBorrow !lender"
            );
        }

        // we could pass the calldata to the lender and have them pass it back, but that seems less safe
        // use storage so that no one can change it
        s.pending_flashloan = true;

        s.pending_lender = address(lender);
        s.pending_action = action;

        lender.flashLoan(this, token, amount, "");
        // s.pending_loan is now `false`

        // copy the call's returned value to return it from this function
        returned = s.pending_return;

        // clear the pending values (pending_flashloan is already `false`)
        delete s.pending_lender;
        delete s.pending_action;
        delete s.pending_return;
    }
    
    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns(bytes32) {
        FlashBorrowerStorage storage s = flashBorrowerStorage();

        // auth
        // pending_loan is like the opposite of a re-entrancy guard
        require(
            s.pending_flashloan,
            "FlashBorrower.onFlashLoan !pending_loan"
        );
        require(
            msg.sender == s.pending_lender,
            "FlashBorrower.onFlashLoan !pending_lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower.onFlashLoan !initiator"
        );
        require(
            Address.isContract(s.pending_action.target),
            "FlashBorrower.onFlashLoan !target"
        );

        // clear pending_loan now in case the delegatecall tries to do something sneaky
        // though i think storing things in state will protect things better
        s.pending_flashloan = false;

        // uncheckedDelegateCall is safe because we just checked that `target` is a contract
        // emit an event with the response?
        bytes memory returned;
        if (s.pending_action.call_type == ArgobytesAuthTypes.Call.DELEGATE) {
            returned = Address2.uncheckedDelegateCall(
                s.pending_action.target,
                s.pending_action.target_calldata,
                "FlashLoanBorrower.onFlashLoan !delegatecall"
            );
        } else {
            returned = Address2.uncheckedCall(
                s.pending_action.target,
                s.pending_action.target_calldata,
                "FlashLoanBorrower.onFlashLoan !call"
            );
        }

        // since we can't return the call's return from here, we store it in state
        s.pending_return = returned;

        // approve paying back the loan
        IERC20(token).approve(s.pending_lender, amount + fee);

        // return their special response
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
