// SPDX-License-Identifier: LGPL-3.0-or-later
/* The Depot is a place to deposit any excess sUSD for others to purchase it with ETH

https://docs.synthetix.io/contracts/depot/
https://docs.synthetix.io/contracts/walkthrus/depot/
https://github.com/Synthetixio/synthetix/blob/develop/contracts/Depot.sol#L20

The depot is capable of trading SNX, too. However, that is only done on Testnets.
*/
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";
import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {
    IAddressResolver
} from "contracts/interfaces/synthetix/IAddressResolver.sol";
import {IDepot} from "contracts/interfaces/synthetix/IDepot.sol";
import {
    IExchangeRates
} from "contracts/interfaces/synthetix/IExchangeRates.sol";
import {ISystemStatus} from "contracts/interfaces/synthetix/ISystemStatus.sol";
import {IProxy} from "contracts/interfaces/synthetix/IProxy.sol";
import {UniversalERC20} from "contracts/library/UniversalERC20.sol";
import {Strings2} from "contracts/library/Strings2.sol";

contract SynthetixDepotAction is AbstractERC20Exchange {
    using UniversalERC20 for IERC20;
    using Strings for uint256;
    using Strings2 for address;

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
