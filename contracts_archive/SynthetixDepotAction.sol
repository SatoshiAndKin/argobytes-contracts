// SPDX-License-Identifier: LGPL-3.0-or-later
/* The Depot is a place to deposit any excess sUSD for others to purchase it with ETH

https://docs.synthetix.io/contracts/depot/
https://docs.synthetix.io/contracts/walkthrus/depot/
https://github.com/Synthetixio/synthetix/blob/develop/contracts/Depot.sol#L20

The depot is capable of trading SNX, too. However, that is only done on Testnets.
*/
pragma solidity 0.8.3;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";
import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {
    IAddressResolver
} from "contracts/external/synthetix/IAddressResolver.sol";
import {IDepot} from "contracts/external/synthetix/IDepot.sol";
import {
    IExchangeRates
} from "contracts/external/synthetix/IExchangeRates.sol";
import {IProxy} from "contracts/external/synthetix/IProxy.sol";

contract SynthetixDepotAction is AbstractERC20Exchange {

    // solium-disable-next-line security/no-assign-params
    function tradeEtherToSynthUSD(
        address to,
        uint256 dest_min_tokens,
        IDepot depot,
        IERC20 sUSD
    ) external payable returnLeftoverEther() {
        uint256 src_balance = address(this).balance;

        depot.exchangeEtherForSynths{value: src_balance}();

        // NOTE! Use the currently active sUSD target, and not the proxy. This should save a little gas
        uint256 dest_balance = sUSD.balanceOf(address(this));

        require(
            dest_balance >= dest_min_tokens,
            "SynthetixDepotAction.tradeEtherToSynthUSD: not enough sUSD received"
        );

        // we know sUSD returns a bool, so no need for safeTransfer
        require(
            sUSD.transfer(to, dest_balance),
            "SynthetixDepotAction.tradeEtherToSynthUSD: transfer failed"
        );
    }
}
