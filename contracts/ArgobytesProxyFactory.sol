// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2017 DappHub, LLC

pragma solidity 0.7.0;

import {DSProxyFactory} from "contracts/interfaces/ds/DSProxy.sol";

import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";

// ArgobytesProxyProxyFactory
// This factory deploys new proxy instances through build()
// Deployed proxy addresses are logged
contract ArgobytesProxyFactory is LiquidGasTokenUser {

    // deploys a new proxy instance
    // sets owner of proxy to caller
    // approve LGT or send ETH to buy LGT
    // TODO: maybe we want to do gas token calculation of maxes offchain. that way miners dont do something sneaky
    function build(address gas_token, address ds_proxy_factory) public payable returns (address payable proxy) {
        uint256 initial_gas = initialGas(gas_token);

        // TODO: too bad they don't do create2 and salts
        proxy = DSProxyFactory(ds_proxy_factory).build(msg.sender);

        freeGasTokens(gas_token, initial_gas);

        // refund any excess ETH
        if (msg.value > 0) {
            (bool success, ) = msg.sender.call{value: address(this).balance}("");
        }
    }
}
