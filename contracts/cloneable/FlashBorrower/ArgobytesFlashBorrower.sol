// SPDX-License-Identifier: LGPL-3.0-or-later
// use the flash loan EIP to receive tokens and then call arbitrary actions
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {ArgobytesClone} from "../ArgobytesClone.sol";

import {Address2} from "contracts/library/Address2.sol";
import {IERC3156FlashBorrower} from "contracts/external/erc3156/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "contracts/external/erc3156/IERC3156FlashLender.sol";

contract ArgobytesFlashBorrower is ArgobytesClone, IERC3156FlashBorrower {

    // the callback's return is already taken
    event TargetReturn(address indexed target, bytes returned);

    // because we make heavy use of delegatecall, we want to make sure our storage is durable
    bytes32 constant FLASH_BORROWER_POSITION = keccak256("argobytes.storage.FlashBorrower.lender") - 1;
    struct FlashBorrowerStorage {
        IERC3156FlashLender lender;
        address pending_target;
        bool pending_loan;
        bytes pending_calldata;
        bytes pending_return;
    }
    function flashBorrowerStorage() internal pure returns (FlashBorrowerStorage storage s) {
        bytes32 position = FLASH_BORROWER_POSITION;
        assembly {
            s.slot := position
        }
    }

    function setLender(address new_lender) external auth {
        FlashBorrowerStorage storage s = flashBorrowerStorage();

        s.lender = IERC3156FlashLender(new_lender);

        // TODO: emit an event
    }

    /// @dev Initiate a flash loan
    function flashBorrow(
        address token,
        uint256 amount,
        address pending_target,
        bytes pending_calldata
    ) public returns (bytes memory returned) {
        FlashBorrowerStorage storage s = flashBorrowerStorage();

        // check auth
        if (msg.sender != owner()) {
            requireAuth(action.target, action.target_calldata.toBytes4());
        }

        // we could pass the calldata to the lender and have them pass it back, but that seems less safe
        // use storage so that no one can change it
        s.pending_target = pending_target;
        s.pending_loan = true;
        s.pending_calldata = pending_calldata;

        s.lender.flashLoan(this, token, amount, "");
        // s.pending_loan is changed to false

        // copy returned value
        returned = s.pending_return;

        // clear the pending values
        s.pending_target = address(0);
        s.pending_calldata = "";
        s.pending_return = "";
    }
    
    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns(bytes32) {
        IERC3156FlashBorrower storage s = lenderStorage();

        // auth
        // pending_loan is like the opposite of a re-entrancy guard
        require(
            s.pending_loan,
            "FlashBorrower !pending_loan"
        );
        require(
            msg.sender == address(lender),
            "FlashBorrower !lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower !initiator"
        );

        // clear pending_loan now in case the delegatecall tries to do something sneaky
        // though i think storing things in state will protect things better
        s.pending_loan = false;

        require(
            Address.isContract(s.pending_target),
            "ArgobytesProxy.execute BAD_TARGET"
        );

        // uncheckedDelegateCall is safe because we just checked that `target` is a contract
        // emit an event with the response?
        bytes memory returned = Address2.uncheckedDelegateCall(
            s.pending_target,
            s.pending_calldata,
            "FlashLoanBorrower.onFlashLoan !delegatecall"
        );

        // approve paying back the loan
        IERC20(token).approve(address(s.lender), amount + fee);

        s.pending_return = returned;

        // return their special response
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
