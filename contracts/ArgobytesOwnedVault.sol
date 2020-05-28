// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {Create2} from "@openzeppelin/utils/Create2.sol";
import {SafeMath} from "@openzeppelin/math/SafeMath.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {GasTokenBurner} from "contracts/GasTokenBurner.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";
import {Strings2} from "contracts/Strings2.sol";
import {
    IArgobytesAtomicTrade
} from "interfaces/argobytes/IArgobytesAtomicTrade.sol";

// WARNING! WARNING! THIS IS NOT A SECRET! THIS IS FOR RECOVERY IN CASE OF BUGS!
// the backdoor is temporary until this is audited and public!
// we actually need it right now since we don't have withdraw functions on ArgobytesOwnedVault
import {Backdoor} from "contracts/Backdoor.sol";


// END WARNING!

contract ArgobytesOwnedVaultDeployer {
    // use CREATE2 to deploy ArgobytesOwnedVault with a salt
    // TODO: steps for using ERADICATE2
    constructor(
        bytes32 salt,
        address[] memory trusted_arbitragers
    ) public payable {
        ArgobytesOwnedVault deployed = new ArgobytesOwnedVault{salt: salt, value: msg.value}(msg.sender, trusted_arbitragers);

        // the vault deploys its own logs. we can grab the contract's address from there
        // emit Deployed(address(deployed));

        // selfdestruct for the gas refund
        selfdestruct(msg.sender);
    }
}


// TODO: re-write this to use the diamond standard
// TODO: expect new versions of GasToken that may have different interfaces. be ready to upgrade them
// it's likely i will want to add new features and suppo
contract ArgobytesOwnedVault is AccessControl, Backdoor, GasTokenBurner {
    using SafeMath for uint256;
    using Strings for uint256;
    using Strings2 for address;
    using UniversalERC20 for IERC20;

    address internal constant ADDRESS_ZERO = address(0x0);
    bytes32 internal constant TRUSTED_ARBITRAGER_ROLE = keccak256(
        "TRUSTED_ARBITRAGER_ROLE"
    );

    /**
     * @notice Deploy the contract.
     * This is payable so that the initial deployment can fund
     */
    constructor(
        address admin,
        address[] memory trusted_arbitragers
    ) public payable {
        // Grant the contract deployer the "backdoor" role
        // BEWARE! this contract can call and delegate call arbitrary functions!
        _setupRole(BACKDOOR_ROLE, admin);

        // Grant the contract deployer the "default admin" role
        // it will be able to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, admin);

        // Grant a vault smart contract address the "trusted arbitrager" role
        // it will be able to call "atomicArbitrage" (WITH OUR FUNDS!)
        // a bot should have this role
        for (uint256 i = 0; i < trusted_arbitragers.length; i++) {
            _setupRole(TRUSTED_ARBITRAGER_ROLE, trusted_arbitragers[i]);
        }
    }

    // allow receiving tokens
    // TODO: add withdraw helpers! (otherwise we can just use the backdoor)
    receive() external payable {}

    function atomicArbitrage(
        address gastoken,
        address atomic_trader,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external returns (uint256 primary_profit) {
        // use address(0) for gastoken to skip gas token burning
        uint256 initial_gas = startFreeGasTokens(gastoken);

        require(
            hasRole(TRUSTED_ARBITRAGER_ROLE, msg.sender),
            "ArgobytesOwnedVault.atomicArbitrage: Caller is not trusted"
        );

        // TODO: debug_require? we only have these for helpful revert messages
        require(
            tokens.length > 0,
            "ArgobytesOwnedVault.atomicArbitrage: tokens.length must be > 0"
        );
        require(
            first_amount > 0,
            "ArgobytesOwnedVault.atomicArbitrage: first_amount must be > 0"
        );

        IERC20 borrow_token = IERC20(tokens[0]);

        uint256 starting_vault_balance = borrow_token.universalBalanceOf(address(this));

        // transfer tokens if we have them
        // if we don't have sufficient tokens, the next contract will borrow from kollateral or some other provider
        if (first_amount <= starting_vault_balance) {
            borrow_token.universalTransfer(atomic_trader, first_amount);

            // clear the kollateral invoker since we won't need it
            kollateral_invoker = ADDRESS_ZERO;
        } else if (starting_vault_balance > 0) {
            require(kollateral_invoker != ADDRESS_ZERO, "ArgobytesOwnedVault.atomicArbitrage: not enough funds. need kollateral_invoker");

            borrow_token.universalTransfer(
                atomic_trader,
                starting_vault_balance
            );
        }
        // else we don't have any of these tokens. they will all come from kollateral or some other flash loan platform

        // notice that this is an atomic trade. it doesn't require a profitable arbitrage. we have to check that ourself after it returns
        // TODO: call a different function or pass zero_address for kollateral_invoker if we don't need outside capital
        try IArgobytesAtomicTrade(atomic_trader).atomicTrade(kollateral_invoker, tokens, first_amount, encoded_actions) {
            // the trade worked!
        } catch Error(string memory reason) {
            // a revert was called inside atomicTrade
            // and a reason string was provided.
            // TODO: is this actually a string or does it have a selector on the front of it?

            // burn our gas token before raising the same revert
            endFreeGasTokens(gastoken, initial_gas);

            // TODO: i bet this is going to make debugging where the revert actually came from annoying
            revert(reason);
        } catch (bytes memory /*lowLevelData*/) {
            // This is executed in case revert() was used
            // or there was a failing assertion, division
            // by zero, etc. inside atomicTrade.

            // burn our gas token before raising the same revert
            endFreeGasTokens(gastoken, initial_gas);

            // TODO: i bet this is going to make debugging where the revert actually came from annoying
            revert("ArgobytesOwnedVault -> IArgobytesAtomicTrade.atomicTrade reverted without a reason");
        }

        // don't trust IArgobytesAtomicTrade.atomicTrade's return. It is safer to check the balance ourselves
        uint256 ending_vault_balance = borrow_token.universalBalanceOf(
            address(this)
        );

        // we allow this to be equal because it's possible that we got our profits somewhere else (like uniswap or kollateral LP fees)
        if (ending_vault_balance < starting_vault_balance) {
            uint256 decreased_amount = starting_vault_balance -
                ending_vault_balance;
            string memory err = string(
                abi.encodePacked(
                    "ArgobytesOwnedVault.atomicArbitrage: Vault balance of ",
                    address(borrow_token).toString(),
                    " decreased by ",
                    decreased_amount.toString()
                )
            );

            // we burn gas token before the very end. that way if we revert, we get more of our gas back and don't actually burn any tokens
            // TODO: is this true? if not, just use the modifier. i think this also means we can free slightly more tokens
            endFreeGasTokens(gastoken, initial_gas);

            revert(err);
        }

        // TODO: return the profit in all tokens so a caller can decide if the trade is worthwhile?
        primary_profit = ending_vault_balance - starting_vault_balance;

        // we made it to the end. burn some gas tokens
        endFreeGasTokens(gastoken, initial_gas);

        // TODO: i thought this was automatic, but i'm not getting anything returned
        return primary_profit;
    }

    // use CREATE2 to deploy with a salt and free gas tokens
    // TODO: function that combines deploy2 and diamondCut
    function deploy2(address gas_token, bytes32 salt, bytes memory bytecode) public payable freeGasTokens(gas_token) returns (address deployed) {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.deploy2: Caller is not an admin"
        );

        deployed = Create2.deploy(msg.value, salt, bytecode);
    }

    function withdrawTo(
        IERC20 token,
        address to,
        uint256 amount
    ) external returns (bool) {
        // TODO: what role? it should be seperate from the deployer
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.withdrawTo: Caller is not an admin"
        );

        return token.universalTransfer(to, amount);
    }

    function withdrawToFreeGas(
        address gas_token,
        IERC20 token,
        address to,
        uint256 amount
    ) external freeGasTokens(gas_token) returns (bool) {
        // TODO: what role? it should be seperate from the deployer
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.withdrawTo: Caller is not an admin"
        );

        return token.universalTransfer(to, amount);
    }
}
