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
// it's likely i will want to add new features and suppo
contract ArgobytesOwnedVault is AccessControl, Backdoor, GasTokenBurner {
    using SafeMath for uint256;
    using Strings for uint256;
    using Strings2 for address;
    using UniversalERC20 for IERC20;

    bytes32 public constant TRUSTED_ARBITRAGER_ROLE = keccak256(
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
        address[] calldata tokens, // Ether or ERC20
        uint256 firstAmount,
        bytes calldata encoded_actions
    ) external returns (uint256 primary_profit) {
        // TODO: make freeing gas tokens optional?
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
            firstAmount > 0,
            "ArgobytesOwnedVault.atomicArbitrage: firstAmount must be > 0"
        );

        IERC20 borrow_token = IERC20(tokens[0]);

        uint256 starting_vault_balance = borrow_token.universalBalanceOf(
            address(this)
        );

        // transfer tokens if we have them
        // if we don't have sufficient tokens, the next contract will borrow from kollateral or some other provider
        if (firstAmount < starting_vault_balance) {
            borrow_token.universalTransfer(atomic_trader, firstAmount);
        } else if (starting_vault_balance > 0) {
            borrow_token.universalTransfer(
                atomic_trader,
                starting_vault_balance
            );
        }
        // else we don't have any of these tokens. they will all come from kollateral or some other flash loan platform

        // notice that this is an atomic trade. it doesn't require a profitable arbitrage. we have to check that ourself
        // TODO: call a different function depending on if we need outside capital or not
        IArgobytesAtomicTrade(atomic_trader).atomicTrade(kollateral_invoker, tokens, firstAmount, encoded_actions);

        // don't use _aat.atomicTrade's return. safer to check the balance ourselves
        uint256 ending_vault_balance = borrow_token.universalBalanceOf(
            address(this)
        );

        // we burn gas token before the very end. that way if we revert, we get more of our gas back and don't actually burn any tokens
        // TODO: is this true? if not, just use the modifier. i think this also means we can free slightly more tokens
        endFreeGasTokens(gastoken, initial_gas);

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
            revert(err);
        }

        // TODO: return the profit in all tokens so a caller can decide if the trade is worthwhile?
        primary_profit = ending_vault_balance - starting_vault_balance;
    }

    // use CREATE2 to deploy with a salt and free gas tokens
    // TODO: OpenZeppelin uses initializer functions for setup. i think we can use the constructor, but we might need to follow them
    // TODO: function that combines deploy2 and diamondCut
    function deploy2(address gastoken, bytes32 salt, bytes memory bytecode) public payable returns (address deployed) {
        uint256 initial_gas = startFreeGasTokens(gastoken);

        // TODO: what role?
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.deploy2: Caller is not an admin"
        );

        deployed = Create2.deploy(msg.value, salt, bytecode);

        endFreeGasTokens(gastoken, initial_gas);
    }

    // this will work for gastoken, too
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
}
