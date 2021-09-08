// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {AddressLib, CallReverted, InvalidTarget} from "contracts/library/AddressLib.sol";

import {ArgobytesAuth} from "contracts/abstract/ArgobytesAuth.sol";

/// @title simple contract for use with a delegatecall proxy
/// @dev contains a very powerful "execute" function! The owner is in full control!
contract ArgobytesProxy is ArgobytesAuth {

    // this function must be able to receive ether if it is expected to trade it
    receive() external payable {}

    /**
     * @notice Call or delegatecall a function on another contract
     * @notice WARNING! This is essentially a backdoor that allows for anything to happen. Without fancy auth isn't DeFi; this is a personal wallet
     * @dev The owner is allowed to call anything. This is helpful in case funds get somehow stuck
     * @dev The owner can authorize other contracts to call this contract
     * TODO: do we care about the return data?
     */
    function execute(Action calldata action) public payable returns (bytes memory action_returned) {
        // check auth
        if (msg.sender != owner()) {
            requireAuth(msg.sender, action.target, action.call_type, bytes4(action.data));
        }

        // TODO: re-entrancy protection? i think our auth check is sufficient

        // TODO: do we really care about this check? calling a non-contract will give "success" even though thats probably not what people wanted to do
        if (!AddressLib.isContract(action.target)) {
            revert InvalidTarget(action.target);
        }

        bool success;

        if (action.call_type == CallType.DELEGATE) {
            (success, action_returned) = action.target.delegatecall(action.data);
        } else if (action.send_balance) {
            (success, action_returned) = action.target.call{value: address(this).balance}(action.data);
        } else {
            (success, action_returned) = action.target.call(action.data);
        }

        if (!success) {
            revert CallReverted(action.target, action.data, action_returned);
        }
    }

    /// @notice Call or delegatecall functions on multiple contracts
    // TODO: do we care about the return data?
    function executeMany(Action[] calldata actions) external payable returns (bytes[] memory responses) {
        uint256 num_actions = actions.length;

        responses = new bytes[](num_actions);

        for (uint256 i = 0; i < num_actions; i++) {
            // TODO: double check auth on this
            responses[i] = execute(actions[i]);
        }

        return responses;
    }

    /// @notice supports all interfaces because this proxy can delegate call anything
    // TODO: maybe safer to use state
    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        // return  interfaceID == 0x01ffc9a7 ||    // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
        //         interfaceID == 0x4e2312e0;      // ERC-1155 `ERC1155TokenReceiver` support (i.e. `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")) ^ bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`).
        return true;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external pure returns(bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external pure returns(bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // TODO: gasless transactions?
}
