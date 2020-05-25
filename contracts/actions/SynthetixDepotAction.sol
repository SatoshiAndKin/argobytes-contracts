// SPDX-License-Identifier: LGPL-3.0-or-later
/* The Depot is a place to deposit any excess sUSD for others to purchase it with ETH

https://docs.synthetix.io/contracts/depot/
https://docs.synthetix.io/contracts/walkthrus/depot/
https://github.com/Synthetixio/synthetix/blob/develop/contracts/Depot.sol#L20

The depot is capable of trading SNX, too. However, that is only done on Testnets.
*/
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

import {IDepot} from "interfaces/synthetix/IDepot.sol";
import {IAddressResolver} from "interfaces/synthetix/IAddressResolver.sol";
import {ISystemStatus} from "interfaces/synthetix/ISystemStatus.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";
import {Strings2} from "contracts/Strings2.sol";

contract SynthetixDepotAction is AbstractERC20Exchange {
    using UniversalERC20 for IERC20;
    using Strings for uint;
    using Strings2 for address;

    struct SynthetixDepotData {
        address depot;
        address sUSD;
    }

    function getAmounts(address token_a, uint256 token_a_amount, address token_b, address resolver)
        external view
        returns (Amount[] memory)
    {
        bytes memory extra_data = abi.encode(resolver);

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(address maker_token, uint taker_wei, address taker_token, bytes memory extra_data)
        public override view
        returns (Amount memory)
    {
        (address resolver) = abi.decode(extra_data, (address));

        Amount memory a = newPartialAmount(maker_token, taker_wei, taker_token);

        address depot = IAddressResolver(resolver).getAddress("Depot");
        address sUSD = IAddressResolver(resolver).getAddress("SynthsUSD");

        SynthetixDepotData memory exchange_data;

        exchange_data.depot = depot;
        exchange_data.sUSD = sUSD;

        if (taker_token == ADDRESS_ZERO && maker_token == sUSD) {
            // eth to sUSD

            // TODO: figure out how to make this work. do we even need it though?
            // status.requireSynthActive("SynthsUSD");

            a.maker_wei = IDepot(depot).synthsReceivedForEther(taker_wei);
            a.selector = this.tradeEtherToSynthUSD.selector;
        } else {
            string memory err = string(abi.encodePacked("SynthetixDepotAction.newAmount: found ", taker_token.toString(), "->", maker_token.toString(), ". supported ", ADDRESS_ZERO.toString(), "->", sUSD.toString()));

            a.error = err;
        }

        a.exchange_data = abi.encode(exchange_data);
        //a.trade_extra_data = "";

        return a;
    }

    // solium-disable-next-line security/no-assign-params
    // TODO: i don't think we need dest_token at all. the caller could just encode based on the selector!
    function tradeEtherToSynthUSD(address depot, address sUSD, address to, uint dest_min_tokens)
        external
        payable
        returnLeftoverEther()
    {
        uint src_balance = address(this).balance;

        IDepot(depot).exchangeEtherForSynths{value: src_balance}();

        uint256 dest_balance = IERC20(sUSD).balanceOf(address(this));

        require(dest_balance >= dest_min_tokens, "SynthetixDepotAction.tradeEtherToSynthUSD: not enough sUSD received");

        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        require(IERC20(sUSD).transfer(to, dest_balance), "SynthetixDepotAction.tradeEtherToSynthUSD: transfer failed");
    }
}
