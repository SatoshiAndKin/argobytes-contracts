// SPDX-License-Identifier: LGPL-3.0-or-later
/* The Depot is a place to deposit any excess sUSD for others to purchase it with ETH

https://docs.synthetix.io/contracts/depot/
https://docs.synthetix.io/contracts/walkthrus/depot/
https://github.com/Synthetixio/synthetix/blob/develop/contracts/Depot.sol#L20

The depot is capable of trading SNX, too. However, that is only done on Testnets.
*/
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";
import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {
    IAddressResolver
} from "contracts/interfaces/synthetix/IAddressResolver.sol";
import {IDepot} from "contracts/interfaces/synthetix/IDepot.sol";
import {
    IExchangeRates
} from "contracts/interfaces/synthetix/IExchangeRates.sol";
import {ISystemStatus} from "contracts/interfaces/synthetix/ISystemStatus.sol";
import {IProxy} from "contracts/interfaces/synthetix/IProxy.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";
import {Strings2} from "contracts/Strings2.sol";

contract SynthetixDepotAction is AbstractERC20Exchange {
    using UniversalERC20 for IERC20;
    using Strings for uint256;
    using Strings2 for address;

    // TODO: we shouldn't need this, but brownie doesn't have a helper for strings -> bytes32
    // TODO: write that helper instead of bloating our very expensive contract deploy
    bytes32 public constant BYTESTR_DEPOT = "Depot";
    bytes32 public constant BYTESTR_EXRATES = "ExchangeRates";
    bytes32 public constant BYTESTR_SUSD = "SynthsUSD";
    bytes32 public constant BYTESTR_STATUS = "SystemStatus";
    bytes32 public constant BYTESTR_ETH = "ETH";

    struct SynthetixExtraData {
        address depot;
        address sUSD;
    }

    function getAmounts(
        address token_a,
        uint256 token_a_amount,
        address token_b,
        address resolver
    ) external view returns (Amount[] memory) {
        bytes memory extra_data = abi.encode(resolver);

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(
        address maker_token_proxy,
        uint256 taker_wei,
        address taker_token,
        bytes memory extra_data
    ) public override view returns (Amount memory) {
        address resolver = abi.decode(extra_data, (address));

        address depot = IAddressResolver(resolver).getAddress(BYTESTR_DEPOT);
        address sUSD = IAddressResolver(resolver).getAddress(BYTESTR_SUSD);

        Amount memory a = newPartialAmount(
            maker_token_proxy,
            taker_wei,
            taker_token
        );

        // maker_token_proxy should be ProxysUSD, and not the underlying currency. This will let us follow synthetix's upgrades
        if (taker_token == ADDRESS_ZERO) {
            try IProxy(maker_token_proxy).target() returns (
                address maker_token
            ) {
                if (maker_token == sUSD) {
                    // eth to sUSD

                    // DO NOT SET a.maker_token to the target. leave it the proxy! `a.maker_token = maker_token;`

                    {
                        address status = IAddressResolver(resolver).getAddress(
                            BYTESTR_STATUS
                        );

                        require(
                            status != ADDRESS_ZERO,
                            "SynthetixDepotAction.newAmount: No address for SystemStatus"
                        );

                        ISystemStatus(status).requireSynthActive(BYTESTR_SUSD);
                    }

                    {
                        address rates = IAddressResolver(resolver).getAddress(
                            BYTESTR_EXRATES
                        );

                        require(
                            rates != ADDRESS_ZERO,
                            "SynthetixDepotAction.newAmount: No address for ExchangeRate"
                        );

                        if (IExchangeRates(rates).rateIsStale(BYTESTR_ETH)) {
                            // rates go stale after 3 hours. If you are on a development network, be sure to reset the blocktime as needed
                            string memory err = string(
                                abi.encodePacked(
                                    "SynthetixDepotAction.newAmount: ETH rate is stale"
                                )
                            );

                            a.error = err;
                        } else {
                            a.maker_wei = IDepot(depot).synthsReceivedForEther(
                                taker_wei
                            );
                            a.selector = this.tradeEtherToSynthUSD.selector;
                        }
                    }
                } else {
                    string memory err = string(
                        abi.encodePacked(
                            "SynthetixDepotAction.newAmount: found ",
                            taker_token.toString(),
                            "->",
                            maker_token.toString(),
                            ". supported ",
                            ADDRESS_ZERO.toString(),
                            "->",
                            sUSD.toString(),
                            " (Via ",
                            maker_token_proxy.toString(),
                            ")"
                        )
                    );

                    a.error = err;
                }
            } catch Error(string memory reason) {
                // This is executed in case
                // revert was called inside getData
                // and a reason string was provided.
                string memory err = string(
                    abi.encodePacked(
                        "SynthetixDepotAction.newAmount: Fetching target of ",
                        maker_token_proxy.toString(),
                        "reverted with ",
                        reason
                    )
                );

                a.error = err;
            } catch (
                bytes memory /*lowLevelData*/
            ) {
                // This is executed in case revert() was used
                // or there was a failing assertion, division
                // by zero, etc. inside getData.
                string memory err = string(
                    abi.encodePacked(
                        "SynthetixDepotAction.newAmount: fetching target of ",
                        maker_token_proxy.toString(),
                        " reverted without reason"
                    )
                );

                a.error = err;
            }
        }

        SynthetixExtraData memory trade_extra_data;

        trade_extra_data.depot = depot;
        trade_extra_data.sUSD = sUSD;

        a.trade_extra_data = abi.encode(trade_extra_data);

        return a;
    }

    function token_supported(address exchange, address token)
        public
        returns (bool)
    {
        revert("wip");
    }

    // solium-disable-next-line security/no-assign-params
    function tradeEtherToSynthUSD(
        address to,
        uint256 dest_min_tokens,
        bytes calldata extra_data
    ) external payable returnLeftoverEther() {
        uint256 src_balance = address(this).balance;

        SynthetixExtraData memory synthetix_data = abi.decode(
            extra_data,
            (SynthetixExtraData)
        );

        IDepot(synthetix_data.depot).exchangeEtherForSynths{
            value: src_balance
        }();

        // NOTE! This is the currently active sUSD target, and not the proxy. This should save a little gas
        uint256 dest_balance = IERC20(synthetix_data.sUSD).balanceOf(
            address(this)
        );

        require(
            dest_balance >= dest_min_tokens,
            "SynthetixDepotAction.tradeEtherToSynthUSD: not enough sUSD received"
        );

        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        // we know sUSD returns a bool, so no need for safeTransfer
        require(
            IERC20(synthetix_data.sUSD).transfer(to, dest_balance),
            "SynthetixDepotAction.tradeEtherToSynthUSD: transfer failed"
        );
    }
}
