// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
// Burns LiquidGasToken (or compatible contracts)
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@OpenZeppelin/token/ERC20/SafeERC20.sol";

import {ArgobytesActor} from "./ArgobytesActor.sol";
import {LiquidGasTokenUser} from "./abstract/LiquidGasTokenUser.sol";
import {ICallee} from "./interfaces/dydx/ICallee.sol";
import {DyDxTypes, ISoloMargin} from "./interfaces/dydx/ISoloMargin.sol";

interface IArgobytesTrader {
    struct Borrow {
        IERC20 token;
        uint256 amount;
        address dest;
    }

    function atomicArbitrage(
        bool free_gas_token,
        bool require_gas_token,
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesActor argobytes_actor,
        ArgobytesActor.Action[] calldata actions
    ) external payable returns (uint256 primary_profit);

    function atomicTrade(
        bool free_gas_token,
        bool require_gas_token,
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesActor argobytes_actor,
        ArgobytesActor.Action[] calldata actions
    ) external payable;

    function dydxFlashArbitrage(
        bool free_gas_token,
        bool require_gas_token,
        address gas_token_from,
        ISoloMargin soloMargin,
        uint256 borrow_id,
        IERC20 borrow_token,
        uint256 borrow_amount,
        address argobytes_actor,
        ArgobytesActor.Action[] calldata actions
    ) external payable returns (uint256 primary_profit);
}

// TODO: this isn't right. this works for the owner account, but needs more thought for authenticating a bot
// TODO: maybe have a function approvedAtomicAbitrage that calls transferFrom. and another that that assumes its used from the owner of the funnds with delegatecall
contract ArgobytesTrader is
    ArgobytesActor,
    IArgobytesTrader,
    ICallee,
    LiquidGasTokenUser
{
    using SafeERC20 for IERC20;

    ISoloMargin constant DYDX_SOLO_MARGIN = ISoloMargin(
        0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e
    );

    // TODO: WETH10 is maybe coming
    address constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // TODO: return gas tokens freed?
    function atomicArbitrage(
        bool free_gas_token,
        bool require_gas_token,
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesActor argobytes_actor,
        ArgobytesActor.Action[] calldata actions
    ) external override payable returns (uint256 primary_profit) {
        uint256 initial_gas = initialGas(free_gas_token);

        uint256[] memory start_balances = new uint256[](borrows.length);

        // record starting token balances to check for increases
        // transfer tokens from msg.sender to arbitrary destinations
        // TODO: what about ETH balances?
        for (uint256 i = 0; i < borrows.length; i++) {
            start_balances[i] = borrows[i].token.balanceOf(borrow_from);

            // TODO: think about this and approvals more
            // TODO: do we want this address(0) check? i think it will be helpful in the case where the clone is holding the coins
            if (borrow_from == address(0)) {
                borrows[i].token.safeTransfer(
                    borrows[i].dest,
                    borrows[i].amount
                );
            } else {
                borrows[i].token.safeTransferFrom(
                    borrow_from,
                    borrows[i].dest,
                    borrows[i].amount
                );
            }
        }

        // we call this as a seperate contract because we don't want any sneaky transferFroms
        // TODO: make sure this actually does what we want by doing a "transferFrom" in the actions!
        // this contract (or the actions) MUST return all borrowed tokens to msg.sender
        // TODO: pass ETH along? this might be helpful for exchanges like 0x. maybe better to borrow WETH for the action
        // TODO: msg.value or address(this).balance?!
        argobytes_actor.callActions{value: msg.value}(actions);

        // make sure the source's balances did not decrease
        // we allow it to be equal because it's possible that we got our profits on another token or from LP fees
        // TODO: we do this in the opposite order that we started in. does that matter?
        for (uint256 i = borrows.length; i > 0; i--) {
            uint256 j = i - 1;

            // return any tokens that the actions didn't already return
            uint256 this_balance = borrows[j].token.balanceOf(address(this));

            borrows[j].token.safeTransfer(borrow_from, this_balance);

            uint256 end_balance = borrows[j].token.balanceOf(borrow_from);

            // make sure the balance increased
            require(
                end_balance >= start_balances[j],
                "ArgobytesTrader: BAD_ARBITRAGE"
            );

            if (j == 0) {
                // TODO? return the profit in all tokens so a caller can decide if the trade is worthwhile
                // we do not need safemath's `sub` here because we check for `end_balance < start_balance` above
                primary_profit = end_balance - start_balances[j];
            }
        }

        // TODO: gas golf placement
        // TODO: what if this takes more ETH and makes the trade not profitable?
        // TODO: pass max ETH spent to this?
        freeOptimalGasTokensFrom(initial_gas, require_gas_token, borrow_from);

        // TODO: refund excess ETH?
    }

    // TODO: return gas tokens freed?
    /**
     * @notice Transfer `first_amount` `tokens[0]`, call some functions, and return tokens to msg.sender.
     * @notice You'll need to call this from another smart contract that has authentication.
     */
    function atomicTrade(
        bool free_gas_token,
        bool require_gas_token,
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesActor argobytes_actor,
        ArgobytesActor.Action[] calldata actions
    ) external override payable {
        uint256 initial_gas = initialGas(free_gas_token);

        // transfer tokens from msg.sender to arbitrary destinations
        // this is dangerous! be careful with this!
        for (uint256 i = 0; i < borrows.length; i++) {
            // TODO: think about this and approvals more
            if (borrow_from == address(0)) {
                borrows[i].token.safeTransfer(
                    borrows[i].dest,
                    borrows[i].amount
                );
            } else {
                borrows[i].token.safeTransferFrom(
                    borrow_from,
                    borrows[i].dest,
                    borrows[i].amount
                );
            }
        }

        // TODO: msg.value or address(this).balance?!
        // we call a seperate contract because we don't want any sneaky transferFroms
        argobytes_actor.callActions{value: msg.value}(actions);

        freeOptimalGasTokensFrom(initial_gas, require_gas_token, borrow_from);

        // TODO: refund excess ETH?
    }

    // flash loan from dydx
    // TODO: return gas tokens freed?
    function dydxFlashArbitrage(
        bool free_gas_token,
        bool require_gas_token,
        address gas_token_from,
        ISoloMargin soloMargin,
        uint256 borrow_id,
        IERC20 borrow_token,
        uint256 borrow_amount,
        address argobytes_actor,
        ArgobytesActor.Action[] calldata actions
    ) external override payable returns (uint256 primary_profit) {
        uint256 initial_gas = initialGas(free_gas_token);

        // we want to give coins to argobytes actor
        // TODO: why is the linter adding extra line breaks?!


            DyDxTypes.AccountInfo[] memory accountInfos
         = new DyDxTypes.AccountInfo[](1);

        // TODO: what account number should we use?
        accountInfos[0] = DyDxTypes.AccountInfo({
            owner: address(this), // with delegatecall, `this` is a proxy
            number: 0
        });

        // setup multiple actions
        DyDxTypes.ActionArgs[] memory operations = new DyDxTypes.ActionArgs[](
            3
        );

        // 1. borrow some token
        // set borrow_id to match https://docs.dydx.exchange/#solo-markets
        // 0 = WETH, 1 = SAI, 2 = USDC, 3 = DAI
        operations[0] = DyDxTypes.ActionArgs({
            actionType: DyDxTypes.ActionType.Withdraw,
            accountId: 0,
            amount: DyDxTypes.AssetAmount({
                sign: false,
                denomination: DyDxTypes.AssetDenomination.Wei,
                ref: DyDxTypes.AssetReference.Delta,
                value: borrow_amount
            }),
            primaryMarketId: borrow_id,
            secondaryMarketId: 0,
            otherAddress: argobytes_actor,
            otherAccountId: 0,
            data: ""
        });

        // 2. call Argobytes actor
        // the last action should return borrowed coins (+ 2 wei fee) to this contract
        operations[1] = DyDxTypes.ActionArgs({
            actionType: DyDxTypes.ActionType.Call,
            accountId: 0,
            amount: DyDxTypes.AssetAmount({
                sign: false,
                denomination: DyDxTypes.AssetDenomination.Wei,
                ref: DyDxTypes.AssetReference.Delta,
                value: 0
            }),
            primaryMarketId: 0,
            secondaryMarketId: 0,
            otherAddress: argobytes_actor,
            otherAccountId: 0,
            data: abi.encode(actions)
        });

        // 3. return what we borrowed (plus a super tiny 2 wei fee)

        // approve the deposit
        // TODO: think about this more. maybe do an infinite approval seperately
        // TODO: safeApprove?
        borrow_token.approve(address(soloMargin), borrow_amount + 2);

        // we have to add 1 or 2 wei depending on the market
        // i think it costs more in gas to check than it does to just always include 2
        operations[2] = DyDxTypes.ActionArgs({
            actionType: DyDxTypes.ActionType.Deposit,
            accountId: 0,
            amount: DyDxTypes.AssetAmount({
                sign: true,
                denomination: DyDxTypes.AssetDenomination.Wei,
                ref: DyDxTypes.AssetReference.Delta,
                value: borrow_amount + 2
            }),
            primaryMarketId: borrow_id,
            secondaryMarketId: 0,
            otherAddress: address(this), // this contract (not argobytes_actor) is going to pay back the debt. with delegatecall, `this` is a proxy
            otherAccountId: 0,
            data: ""
        });

        // do all the operations
        soloMargin.operate(accountInfos, operations);

        // we could check for actual profit here, but i don't think its necessary

        // since actions might have highly variable gas costs, we calculate the gas tokens needed
        // TODO: do this even if soloMargin reverts
        freeOptimalGasTokensFrom(
            initial_gas,
            require_gas_token,
            gas_token_from
        );
    }

    /*
    Entrypoint for dYdX operations (from ICallee).

    TODO: do we care about the first two args (sender or accountInfo)?
    */
    function callFunction(
        address,
        DyDxTypes.AccountInfo calldata,
        bytes calldata data
    ) external override {
        return this.callActions(abi.decode(data, (Action[])));
    }
}
