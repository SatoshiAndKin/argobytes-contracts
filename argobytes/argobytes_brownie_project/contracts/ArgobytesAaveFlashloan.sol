// SPDX-License-Identifier: MPL-2.0
// TODO: Make this Cloneable by using ArgobytesAuth?
pragma solidity 0.8.5;
pragma abicoder v2;

import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";

/// @dev DO NOT approve this contract to take your tokens!
contract ArgobytesAaveFlashloan {
    using SafeERC20 for IERC20;

    error CallReverted(address target, bytes data, bytes errordata);

    enum CallType {
        DELEGATE,
        CALL
    }

    struct Action {
        address payable target;
        CallType call_type;
        bytes data;
    }

    address immutable owner;
    address immutable lender;

    constructor(address _owner, address _lender) {
        owner = _owner;
        lender = _lender;
    }

    // TODO: this is not the right action. we might want dellegate calls
    function encodeData(Action[] calldata actions) external view returns (bytes memory data) {
        data = abi.encode(actions);
    }

    function _executeAction(Action memory action) internal {
        // TODO: do we really care about this check? calling a non-contract will give "success" even though thats probably not what people wanted to do
        // if (!AddressLib.isContract(action.target)) {
        //     revert InvalidTarget(action.target);
        // }

        bool success;
        bytes memory action_returned;

        if (action.call_type == CallType.DELEGATE) {
            (success, action_returned) = action.target.delegatecall(action.data);
        } else {
            // TODO: option to send ETH value?
            (success, action_returned) = action.target.call(action.data);
        }

        if (!success) {
            revert CallReverted(action.target, action.data, action_returned);
        }

        // TODO: return action_returned?
    }

    // gets tokens/WETH via a V2 flash swap, call arbitrary actions, repays V2, and keeps the rest!
    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool)
    {
        require(msg.sender == lender, "bad lender"); // make sure Aave is calling us
        require(initiator == owner, "bad initiator"); // very basic calldata stealing protection. weak auth 

        // decode data for multicall
        Action[] memory actions = abi.decode(params, (Action[]));

        // do arbitrary things with the tokens
        // the actions must send enough token back here to pay the flash loan
        { // scope for num_actions
            uint256 num_actions = actions.length;
            for (uint256 i = 0; i < num_actions; i++) {
                _executeAction(actions[i]);
            }
        }

        uint num_assets = assets.length;
        for (uint i = 0; i < num_assets; i++) {
            uint amount_owed = amounts[i] + premiums[i];

            IERC20 asset = IERC20(assets[i]);

            uint balance = asset.balanceOf(address(this));

            require(balance > amount_owed, "bad arb!");

            // Approve the LendingPool contract to *pull* the owed amount
            asset.approve(msg.sender, amount_owed);
            // keep the rest as profit
            // TODO: tips?
            // TODO: should profits go to owner or initiator?
            asset.safeTransfer(owner, balance - amount_owed);
        }
    }
}
