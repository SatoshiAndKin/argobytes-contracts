// SPDX-License-Identifier: LGPL-3.0-or-later
/* The Depot is a place to deposit any excess sUSD for others to purchase it with ETH

https://docs.synthetix.io/contracts/depot/
https://docs.synthetix.io/contracts/walkthrus/depot/
https://github.com/Synthetixio/synthetix/blob/develop/contracts/Depot.sol#L20

The depot is capable of trading SNX, too. However, that is only done on Testnets.
*/
pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {Strings} from "@openzeppelin/utils/Strings.sol";

import {ICurveFi} from "interfaces/curvefi/ICurveFi.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {Ownable2} from "contracts/Ownable2.sol";
import {Strings2} from "contracts/Strings2.sol";
import {IERC20, SafeERC20, UniversalERC20} from "contracts/UniversalERC20.sol";

contract CurveFiAction is AbstractERC20Exchange, Ownable2 {
    using UniversalERC20 for IERC20;
    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Strings2 for address;

    // mappings of token addresses to curve indexes PLUS ONE!
    // we add one to our indexes because fetching an unknown address will return 0!
    mapping(address => mapping(address => int128)) _coins;
    mapping(address => mapping(address => int128)) _underlying_coins;

    constructor(address owner) public Ownable2(owner) {}

    function token_supported(address exchange, address token)
        public
        returns (bool)
    {
        return
            (_coins[exchange][token] > 0) ||
            (_underlying_coins[exchange][token] > 0);
    }

    function saveExchange(address exchange, int128 n) public onlyOwner {
        // i'd like this to be open, but i feel like people could grief. maybe require a fee that goes to ownedVault? or require ownership of an erc20?

        for (int128 i = 0; i < n; i++) {
            // this reverts on an invalid i
            address coin = ICurveFi(exchange).coins(i);

            if (coin != ADDRESS_ZERO) {
                string memory err = abi.encodePacked(
                    "CurveFiAction: Exchange ",
                    exchange.toString(),
                    "is missing coin #",
                    i
                );
                revert(err);
            }

            // Approve the transfer of tokens from this contract to the exchange contract
            // we only do this if it isn't already set because sometimes exchanges have the same asset multiple times
            if (IERC20(coin).allowance(address(this), address(exchange)) == 0) {
                IERC20(coin).safeApprove(address(exchange), uint256(-1));
            }

            // save the coin with an index of + 1. this lets us be sure that 0 means the coin is unsupported
            _coins[exchange][coin] = i + 1;

            // this reverts on an invalid i
            address underlying_coin = ICurveFi(exchange).underlying_coins(i);

            if (underlying_coin != ADDRESS_ZERO) {
                // not all of the exchanges have an underlying
                if (
                    IERC20(underlying_coin).allowance(
                        address(this),
                        address(exchange)
                    ) == 0
                ) {
                    IERC20(underlying_coin).safeApprove(
                        address(exchange),
                        uint256(-1)
                    );
                }

                // save the underlying_coin with an index of + 1. this lets us be sure that 0 means the coin is unsupported
                _underlying_coins[exchange][underlying_coin] = i + 1;
            }
        }

        // TODO: save the exchange address, too?
    }

    function getAmounts(
        address token_a,
        uint256 token_a_amount,
        address token_b,
        address exchange
    ) external view returns (Amount[] memory) {
        bytes memory extra_data = abi.encode(exchange);

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(
        address maker_token,
        uint256 taker_wei,
        address taker_token,
        bytes memory extra_data
    ) public override view returns (Amount memory) {
        address exchange = abi.decode(extra_data, (address));

        Amount memory a = newPartialAmount(maker_token, taker_wei, taker_token);

        // i is the taker token
        int128 i = _coins[exchange][taker_token];
        // j is the maker token
        int128 j = _coins[exchange][maker_token];

        if (i == 0 || j == 0) {
            // at least one of the coins was not found
            int128 underlying_i = _underlying_coins[exchange][taker_token];
            int128 underlying_j = _underlying_coins[exchange][maker_token];

            if (underlying_i == 0 || underlying_j == 0) {
                // no _coin and no _underlying_coin found. cancel
                string memory err;
                if (i + j + underlying_i + underlying_j == 0) {
                    err = string(
                        abi.encodePacked(
                            "CurveFiAction.newAmount: entirely unsupported coins ",
                            maker_token.toString(),
                            " and ",
                            taker_token.toString()
                        )
                    );
                } else if (i + j + underlying_i == 0 && underlying_j > 0) {
                    err = string(
                        abi.encodePacked(
                            "CurveFiAction.newAmount: unsupported underlying taker coin ",
                            taker_token.toString()
                        )
                    );
                } else if (i + j + underlying_j == 0 && underlying_i > 0) {
                    err = string(
                        abi.encodePacked(
                            "CurveFiAction.newAmount: unsupported underlying maker coin ",
                            maker_token.toString()
                        )
                    );
                } else if (i + j == 0) {
                    err = string(
                        abi.encodePacked(
                            "CurveFiAction.newAmount: unsupported coins ",
                            maker_token.toString(),
                            " and ",
                            taker_token.toString()
                        )
                    );
                } else if (i > 0) {
                    err = string(
                        abi.encodePacked(
                            "CurveFiAction.newAmount: unsupported taker coin ",
                            taker_token.toString()
                        )
                    );
                } else if (j > 0) {
                    err = string(
                        abi.encodePacked(
                            "CurveFiAction.newAmount: unsupported maker coin ",
                            maker_token.toString()
                        )
                    );
                }

                a.error = err;

                return a;
            }

            // now that we know we have supported underlying_coins. fix the indexes to match what CurveFi expects
            underlying_i -= 1;
            underlying_j -= 1;

            a.maker_wei = ICurveFi(exchange).get_dy_underlying(
                underlying_i,
                underlying_j,
                taker_wei
            );
            a.selector = this.tradeUnderlying.selector;
        } else {
            // both i and j are set! coins should be valid

            // now that we know we have supported coins. fix the indexes to match what CurveFi expects
            i -= 1;
            j -= 1;

            a.maker_wei = ICurveFi(exchange).get_dy(i, j, taker_wei);
            a.selector = this.trade.selector;
        }

        // TODO: use a struct
        a.trade_extra_data = abi.encode(exchange, i, j);

        // a.exchange_data = "";

        return a;
    }

    // trade wrapped stablecoins
    // solium-disable-next-line security/no-assign-params
    function trade(
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        bytes calldata extra_data
    ) external returnLeftoverToken(src_token, ADDRESS_ZERO) {
        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        (address exchange, int128 i, int128 j) = abi.decode(
            extra_data,
            (address, int128, int128)
        );

        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(src_amount > 0, "CurveFiAction.trade: NO_SOURCE_AMOUNT");

        // do the trade (approve was already called)
        ICurveFi(exchange).exchange(i, j, src_amount, dest_min_tokens);

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(
            dest_balance >= dest_min_tokens,
            "CurveFiAction.trade: LOW_DEST_BALANCE"
        );

        // forward the tokens that we bought
        IERC20(dest_token).safeTransfer(to, dest_balance);
    }

    // trade stablecoins
    // we use ADDRESS_ZERO for returnLeftoverToken because we do NOT want to clear our infinite approvals
    // solium-disable-next-line security/no-assign-params
    function tradeUnderlying(
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        bytes calldata extra_data
    ) external returnLeftoverToken(src_token, ADDRESS_ZERO) {
        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        (address exchange, int128 i, int128 j) = abi.decode(
            extra_data,
            (address, int128, int128)
        );

        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(
            src_amount > 0,
            "CurveFiAction.tradeUnderlying: NO_SOURCE_AMOUNT"
        );

        // do the trade (approve was already called)
        ICurveFi(exchange).exchange_underlying(
            i,
            j,
            src_amount,
            dest_min_tokens
        );

        // check that we received what we expected
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(
            dest_balance >= dest_min_tokens,
            "CurveFiAction.tradeUnderlying: LOW_DEST_BALANCE"
        );

        // forward the tokens that we bought
        IERC20(dest_token).safeTransfer(to, dest_balance);
    }
}
