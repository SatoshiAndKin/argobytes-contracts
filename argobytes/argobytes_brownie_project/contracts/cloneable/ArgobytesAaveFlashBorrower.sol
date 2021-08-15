// SPDX-License-Identifier: MPL-2.0
// TODO: Make this Cloneable by using ArgobytesAuth?
pragma solidity 0.8.5;
pragma abicoder v2;

import {AddressLib, CallReverted, InvalidTarget} from "contracts/library/AddressLib.sol";
import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";

import {IERC3156FlashBorrower} from "contracts/external/erc3156/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "contracts/external/erc3156/IERC3156FlashLender.sol";

import {ArgobytesProxy} from "./ArgobytesProxy.sol";

error BadLender(address);

interface ILendingPoolAddressesProviderRegistry {
  function getAddressesProvidersList() external view returns (IAaveLendingPoolAddressesProvider[] memory);
}

interface IAaveLendingPoolAddressesProvider {
    function getLendingPool() external returns (address);
}

/// @title Target for Aave's LendingPool.flashLoan
/// @dev DO NOT approve this contract to take your tokens!
contract ArgobytesAaveFlashBorrower is ArgobytesProxy {
    using SafeERC20 for IERC20;

    event AddLendingPool(address pool);
    event RemoveLendingPool(address pool);

    ILendingPoolAddressesProviderRegistry immutable lender_provider_registry;

    /// TODO: diamond storage?
    mapping(address => bool) public lending_pools;

    constructor(ILendingPoolAddressesProviderRegistry _lender_provider_registry) {
        lender_provider_registry = _lender_provider_registry;
    }

    /// @notice update the lender
    function updateLendingPools() external auth(CallType.ADMIN) {
        IAaveLendingPoolAddressesProvider[] memory lending_pool_providers = lender_provider_registry.getAddressesProvidersList();
        uint num_lending_pools = lending_pool_providers.length;
        for (uint i = 0; i < num_lending_pools; i++) {
            address lending_pool = lending_pool_providers[i].getLendingPool();
            lending_pools[lending_pool] = true;
            emit AddLendingPool(lending_pool);
        }
    }

    function removeLendingPool(address lending_pool) external auth(CallType.ADMIN) {
        delete lending_pools[lending_pool];
        emit RemoveLendingPool(lending_pool);
    }

    // TODO: this is not the right action. we might want dellegate calls
    function encodeFlashParams(Action[] calldata actions) external view returns (bytes memory data) {
        data = abi.encode(actions);
    }

    /// @dev This function is called by the lender after your contract has received the flash loaned amount
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        // make sure Aave is calling us
        if (!lending_pools[msg.sender]) {
            revert BadLender(msg.sender);
        }

        address owner = owner();

        {
            // scope to avoid stack too deep errors
            // decode data for multicall
            Action[] memory actions = abi.decode(params, (Action[]));

            // do things with the tokens
            // the actions **must** send enough token back here to pay the flash loan
            bool initiator_not_owner = initiator != owner;
            uint256 num_actions = actions.length;
            Action memory action;
            for (uint256 i = 0; i < num_actions; i++) {
                action = actions[i];

                // auth individual actions
                // a common pattern is delegate calling a known safe contract that doesn't call arbitrary actions
                if (initiator_not_owner) {
                    requireAuth(initiator, action.target, action.call_type, bytes4(action.data));
                }

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
            }
        }

        // TODO: i'd save assets.length in a variable, but stack too deep
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20 asset = IERC20(assets[i]);

            // Approve the LendingPool contract to *pull* the owed amount
            uint256 amount = amounts[i] + premiums[i];
            asset.approve(msg.sender, amount);

            // send on the rest as profit
            amount = asset.balanceOf(address(this)) - amount;
            asset.safeTransfer(owner, amount);
        }

        return true;
    }
}
