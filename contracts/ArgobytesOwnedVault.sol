// Store profits and provide them for flash lending
pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import {AccessControl} from "OpenZeppelin/openzeppelin-contracts@3.0.0-rc.1/contracts/access/AccessControl.sol";
import {SafeMath} from "OpenZeppelin/openzeppelin-contracts@3.0.0-rc.1/contracts/math/SafeMath.sol";
import {Strings} from "OpenZeppelin/openzeppelin-contracts@3.0.0-rc.1/contracts/utils/Strings.sol";

import {GasTokenBurner} from "contracts/GasTokenBurner.sol";
import {IERC20, UniversalERC20} from "contracts/UniversalERC20.sol";
import {Strings2} from "contracts/Strings2.sol";
import {IArgobytesAtomicTrade} from "interfaces/argobytes/IArgobytesAtomicTrade.sol";

// WARNING! WARNING! THIS IS NOT A SECRET! THIS IS FOR RECOVERY IN CASE OF BUGS!
// the backdoor is temporary until this is audited and public!
// we actually need it right now since we don't have withdraw functions on ArgobytesOwnedVault
import {Backdoor} from "contracts/Backdoor.sol";
// END WARNING!

contract ArgobytesOwnedVault is AccessControl, Backdoor, GasTokenBurner {
    using SafeMath for uint256;
    using Strings for uint256;
    using Strings2 for address;
    using UniversalERC20 for IERC20;

    bytes32 internal constant TRUSTED_ARBITRAGER_ROLE = keccak256("TRUSTED_ARBITRAGER_ROLE");

    IArgobytesAtomicTrade _aat;

    /**
     * @notice Deploy the contract.
     */
    constructor(address gas_token, address[] memory trusted_arbitragers)
        public
        GasTokenBurner(gas_token)
    {
        // Grant the contract deployer the "backdoor" role
        // BEWARE! this contract can call and delegate call arbitrary functions!
        _setupRole(BACKDOOR_ROLE, msg.sender);

        // Grant the contract deployer the "default admin" role
        // it will be able to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant a vault smart contract address the "trusted arbitrager" role
        // it will be able to call "atomicArbitrage" (WITH OUR FUNDS!)
        // a bot should have this role
        for (uint i = 0; i < trusted_arbitragers.length; i++) {
            _setupRole(TRUSTED_ARBITRAGER_ROLE, trusted_arbitragers[i]);
        }

        // you still need to call setArgobytesAtomicArbitrage!
        // TODO: if we ever have multiple contracts for arbitrage, it might be worth taking the address as calldata, but this is simpler for now
    }

    // allow receiving tokens
    // TODO: add withdraw helpers! (otherwise we can just use the backdoor)
    receive() external payable { }

    // TODO: address payable once rust's ethabi is smarter
    function setArgobytesAtomicTrade(address aaa) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "ArgobytesOwnedVault: Caller is not default admin");

        // TODO: emit an event

        _aat = IArgobytesAtomicTrade(payable(aaa));
    }

    function atomicArbitrage(
        address[] calldata tokens,  // Ether or ERC20
        uint256 tokenAmount,
        bytes calldata encoded_actions
    )
        external
        returns (uint256 primary_profit)
    {
        // TODO: make freeing gas tokens optional? 
        uint256 initial_gas = startFreeGasTokens();

        require(hasRole(TRUSTED_ARBITRAGER_ROLE, msg.sender), "ArgobytesOwnedVault.atomicArbitrage: Caller is not trusted");

        // TODO: debug_require? we only have these for helpful revert messages
        require(tokens.length > 0, "ArgobytesOwnedVault.atomicArbitrage: tokens.length must be > 0");
        require(tokenAmount > 0, "ArgobytesOwnedVault.atomicArbitrage: tokenAmount must be > 0");

        IERC20 borrow_token = IERC20(tokens[0]);

        uint256 starting_vault_balance = borrow_token.universalBalanceOf(address(this));

        // transfer tokens if we have them
        // if we don't have sufficient tokens, the next contract will borrow from kollateral or some other provider
        if (tokenAmount < starting_vault_balance) {
            borrow_token.universalTransfer(address(_aat), tokenAmount);
        } else if (starting_vault_balance > 0) {
            borrow_token.universalTransfer(address(_aat), starting_vault_balance);
        }

        require(address(_aat) != address(0x0), "ArgobytesOwnedVault.atomicArbitrage: require setArgobytesAtomicArbitrage");

        // notice that this is an atomic trade. it doesn't require a profitable arbitrage. we have to check that ourself
        _aat.atomicTrade(tokens, tokenAmount, encoded_actions);

        // don't use _aat.atomicTrade's return. safer to check the balance ourselves
        uint256 ending_vault_balance = borrow_token.universalBalanceOf(address(this));

        // we burn gas token before the very end. that way if we revert, we get more of our gas back and don't actually burn any tokens
        // TODO: is this true? if not, just use the modifier
        endFreeGasTokens(initial_gas);

        // we allow this to be equal because it's possible that we got our profits somewhere else (like uniswap or kollateral LP fees)
        if (ending_vault_balance < starting_vault_balance) {
            uint256 decreased_amount = starting_vault_balance - ending_vault_balance;
            string memory err = string(abi.encodePacked("ArgobytesOwnedVault.atomicArbitrage: Vault balance of ", address(borrow_token).fromAddress(), " did not increase. Decreased by ", decreased_amount.fromUint256()));
            revert(err);
        }

        // TODO: return the profit in all tokens so a caller can decide if the trade is worthwhile?
        primary_profit = ending_vault_balance - starting_vault_balance;
    }

    function withdrawTo(IERC20 token, address to, uint256 amount) external returns(bool) {
        // TODO: what role? it should be seperate from the deployer
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "ArgobytesOwnedVault.withdrawTo: Caller is not an admin");

        return token.universalTransfer(to, amount);
    }
}
