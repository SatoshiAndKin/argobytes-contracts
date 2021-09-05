// SPDX-License-Identifier: MPL-2.0
// TODO: Make this Cloneable by using ArgobytesAuth?
pragma solidity 0.8.7;
pragma abicoder v2;

import {AddressLib, CallReverted, InvalidTarget} from "contracts/library/AddressLib.sol";
import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";
import {IAaveLendingPoolAddressesProvider, IAaveLendingPoolAddressesProviderRegistry} from "contracts/external/aave/Aave.sol";

import {ArgobytesProxy} from "./ArgobytesProxy.sol";

error BadLender(address);

/// @title Flash borrow from approved tokes or from Aave V2's LendingPool.flashLoan
contract ArogbytesFlashBorrower is ArgobytesProxy {
    using SafeERC20 for IERC20;

    event AddLendingPool(address pool);
    event RemoveLendingPool(address pool);

    IAaveLendingPoolAddressesProviderRegistry immutable lender_provider_registry;

    mapping(address => bool) public lending_pools;

    constructor(IAaveLendingPoolAddressesProviderRegistry _lender_provider_registry) {
        lender_provider_registry = _lender_provider_registry;

        // by default, you can flash loan from yourself. this can be removed
        lending_pools[address(this)] = true;
        emit AddLendingPool(address(this));
    }

    /// @notice update the lender
    /// @dev youu can do this off chain and call addLendingPool yourself, but this is easier to delegate
    function updateAaveLendingPools() external auth(CallType.ADMIN) {
        IAaveLendingPoolAddressesProvider[] memory lending_pool_providers = lender_provider_registry
            .getAddressesProvidersList();
        uint256 num_lending_pools = lending_pool_providers.length;
        for (uint256 i = 0; i < num_lending_pools; i++) {
            address lending_pool = lending_pool_providers[i].getLendingPool();
            lending_pools[lending_pool] = true;
            emit AddLendingPool(lending_pool);
        }
    }

    /// @notice Allow flash loans from an Aave V2 Lending Pool (or compatible contract)
    function addLendingPool(address lending_pool) external auth(CallType.ADMIN) {
        lending_pools[lending_pool] = true;
        emit AddLendingPool(lending_pool);
    }

    /// @notice Deny flash loans from an Aave V2 Lending Pool (or compatible contract)
    function removeLendingPool(address lending_pool) external auth(CallType.ADMIN) {
        delete lending_pools[lending_pool];
        emit RemoveLendingPool(lending_pool);
    }

    /// @notice ABI encode actions for use as a flash loan's "params" function
    // TODO: do the encoding offchain
    function encodeFlashParams(Action[] calldata actions) external view returns (bytes memory data) {
        data = abi.encode(actions);
    }

    /// @notice transfer tokens from lenders, do whatever with them, repay them, send profits to the owner
    /// @dev If you don't have enough tokens have Aave's LendingPool executeOperation here instead
    /// @dev lenders must approve this contract to use their tokens!
    /// @dev "params" should be abi encoded ActionTypes.Actions
    // TODO: write a fork of this that works with fee on transfer tokens?
    function flashloanForOwner(
        address[] calldata lenders,
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata params
    ) external payable auth(CallType.CALL) {
        // TODO: are modifiers inefficient still?

        uint256 assetsLength = assets.length;

        { // scope for premiums to avoid stack too deep errors
            // no fees for now
            // TODO: we might actually want to have some sort of premiums one day, but not onw
            uint256[] memory premiums = new uint256[](assetsLength);

            // borrow tokens
            { // scope for lender to avoid stack too deep errors
                address lender;
                for (uint i = 0; i < assetsLength; i++) {
                    lender = lenders[i] == address(0) ? owner() : lenders[i];
                    IERC20(assets[i]).safeTransferFrom(lender, address(this), amounts[i]);
                }
            }

            // call the EXTERNAL function executeOperation so that msg.sender is this.
            // this is allowed by default, but access can be revoked
            // TODO: check that this returns true? it never returns false though. it reverts if anything fails.
            this.executeOperation(
                assets,
                amounts,
                premiums,
                msg.sender,
                params
            );
        }

        // return tokens to the lenders
        // profits were alredy transfered to the owner by executeOperation
        for (uint i = 0; i < assetsLength; i++) {
            // return borrowed tokens
            IERC20(assets[i]).safeTransfer(lenders[i], amounts[i]);
        }
    }

    /// @notice This function is called by the lender after your contract has received the flash loaned amount
    /// @dev ALL profits are sent to the owner, NOT the initiator!
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

        for (uint256 i = 0; i < assets.length; i++) {
            IERC20 asset = IERC20(assets[i]);
            require(asset.balanceOf(address(this)) >= amounts[i], "bad starting balance");
        }

        address my_owner = owner();

        {
            // scope to avoid stack too deep errors
            // decode data for multicall
            Action[] memory actions = abi.decode(params, (Action[]));

            // do things with the tokens
            // the actions **must** send enough token back here to pay the flash loan
            bool initiator_not_owner = initiator != my_owner;
            uint256 num_actions = actions.length;
            Action memory action;
            for (uint256 i = 0; i < num_actions; i++) {
                action = actions[i];

                // auth individual actions
                // a common pattern is delegate calling a known safe contract that doesn't call arbitrary actions
                // do NOT do things like authorizing calls to token transfers!
                if (initiator_not_owner) {
                    requireAuth(initiator, action.target, action.call_type, bytes4(action.data));
                }

                bool success;
                bytes memory action_returned;

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
        }

        // TODO: i'd save assets.length in a variable, but stack too deep
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20 asset = IERC20(assets[i]);

            // we need this much to pay back the flash loan
            uint256 amount = amounts[i] + premiums[i];

            // Approve the LendingPool contract to *pull* the owed amount
            asset.safeApprove(msg.sender, amount);

            // send on the rest as profit
            amount = asset.balanceOf(address(this)) - amount;

            // leave 1 wei behind for gas savings
            if (amount > 1) {
                asset.safeTransfer(my_owner, amount - 1);
            }
        }

        return true;
    }
}
