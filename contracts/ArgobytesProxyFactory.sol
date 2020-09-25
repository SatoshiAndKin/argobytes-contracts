// SPDX-License-Identifier: LGPL-3.0-or-later
// deploy delegatecall proxies and free liquid gas tokens.
pragma solidity 0.7.0;

import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";
import {ArgobytesProxy} from "contracts/ArgobytesProxy.sol";

interface IArgobytesProxyFactory {
    event NewProxy(address indexed sender, address indexed first_admin, address proxy);

    function buildProxy(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt
    ) external payable returns (address deployed);

    function buildProxy(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        address first_owner
    ) external payable returns (address deployed);

    function deploy2(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) external payable returns (address deployed);
}

// ArgobytesDeployer
// deploy contracts and burn gas tokens
// only set gas_token if the contract is large and gas prices are high
// LGT's deploy helper only buys (we might have our own tokens)
contract ArgobytesProxyFactory is IArgobytesProxyFactory, LiquidGasTokenUser {

    function buildProxy(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt
    ) external override payable returns (address deployed) {
        deployed = this.buildProxy(gas_token_amount, require_gas_token, salt, msg.sender);
    }

    function buildProxy(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        address first_owner
    ) external override payable returns (address deployed) {
        // since this deployment cost can be known, we free a specific amount tokens
        freeGasTokens(gas_token_amount, require_gas_token);

        deployed = address(new ArgobytesProxy{salt: salt}(first_owner));

        // refund any excess ETH
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = msg.sender.call{value: balance}("");
        }
    }

    function deploy2(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) external override payable returns (address deployed) {
        // since this deployment cost can be known, we free a specific amount tokens
        freeGasTokens(gas_token_amount, require_gas_token);

        deployed = Create2.deploy(0, salt, bytecode);

        if (extradata.length > 0) {
            (bool success, ) = deployed.call(extradata);
            require(success, "extradata call reverted");
        }

        // refund any excess ETH
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = msg.sender.call{value: balance}("");
        }
    }
}
