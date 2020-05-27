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

import {IAddressResolver} from "interfaces/synthetix/IAddressResolver.sol";
import {IDepot} from "interfaces/synthetix/IDepot.sol";
import {IExchangeRates} from "interfaces/synthetix/IExchangeRates.sol";
import {ISystemStatus} from "interfaces/synthetix/ISystemStatus.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";
import {Strings2} from "contracts/Strings2.sol";

contract SynthetixDepotAction is AbstractERC20Exchange {
    using UniversalERC20 for IERC20;
    using Strings for uint;
    using Strings2 for address;

    // TODO: we shouldn't need this, but i'm having trouble setting up fixture
    bytes32 public constant BYTESTR_DEPOT = "Depot";
    bytes32 public constant BYTESTR_EXRATES = "ExchangeRates";
    bytes32 public constant BYTESTR_SUSD = "SynthsUSD";
    bytes32 public constant BYTESTR_STATUS = "SystemStatus";
    bytes32 public constant BYTESTR_ETH = "ETH";

    struct SynthetixExtraData {
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

        address depot = IAddressResolver(resolver).getAddress(BYTESTR_DEPOT);
        address sUSD = IAddressResolver(resolver).getAddress(BYTESTR_SUSD);

        SynthetixExtraData memory trade_extra_data;

        trade_extra_data.depot = depot;
        trade_extra_data.sUSD = sUSD;

        if (taker_token == ADDRESS_ZERO && maker_token == sUSD) {
            // eth to sUSD

            {
                address status = IAddressResolver(resolver).getAddress(BYTESTR_STATUS);

                require(status != ADDRESS_ZERO, "SynthetixDepotAction.newAmount: No address for SystemStatus");

                ISystemStatus(status).requireSynthActive(BYTESTR_SUSD);
            }

            {
                address rates = IAddressResolver(resolver).getAddress(BYTESTR_EXRATES);

                require(rates != ADDRESS_ZERO, "SynthetixDepotAction.newAmount: No address for ExchangeRate");

                if (IExchangeRates(rates).rateIsStale(BYTESTR_ETH)) {
                    // TODO: i think ganache is doing something incorrect here. debug more
                    string memory err = string(abi.encodePacked("SynthetixDepotAction.newAmount: ETH rate is stale"));

                    a.error = err;
                } else {
                    a.maker_wei = IDepot(depot).synthsReceivedForEther(taker_wei);
                    a.selector = this.tradeEtherToSynthUSD.selector;
                }
            }
        } else {
            string memory err = string(abi.encodePacked("SynthetixDepotAction.newAmount: found ", taker_token.toString(), "->", maker_token.toString(), ". supported ", ADDRESS_ZERO.toString(), "->", sUSD.toString()));

            a.error = err;
        }

        // a.exchange_data = abi.encode(exchange_data);
        a.trade_extra_data = abi.encode(trade_extra_data);

        return a;
    }

    // solium-disable-next-line security/no-assign-params
    // TODO: i don't think we need dest_token at all. the caller could just encode based on the selector!
    function tradeEtherToSynthUSD(address to, uint dest_min_tokens, bytes calldata extra_data)
        external
        payable
        returnLeftoverEther()
    {
        uint src_balance = address(this).balance;

        (SynthetixExtraData memory synthetix_data) = abi.decode(extra_data, (SynthetixExtraData));

        IDepot(synthetix_data.depot).exchangeEtherForSynths{value: src_balance}();

        uint256 dest_balance = IERC20(synthetix_data.sUSD).balanceOf(address(this));

        require(dest_balance >= dest_min_tokens, "SynthetixDepotAction.tradeEtherToSynthUSD: not enough sUSD received");

        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        // we know sUSD returns a bool, so no need for safeTransfer
        require(IERC20(synthetix_data.sUSD).transfer(to, dest_balance), "SynthetixDepotAction.tradeEtherToSynthUSD: transfer failed");
    }
}
