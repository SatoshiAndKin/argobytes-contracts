/* The Depot is a place to deposit any excess sUSD for others to purchase it with ETH

https://docs.synthetix.io/contracts/depot/
https://docs.synthetix.io/contracts/walkthrus/depot/
https://github.com/Synthetixio/synthetix/blob/develop/contracts/Depot.sol#L20

The depot is capable of trading SNX, too. However, that is only done on Testnets.
*/
pragma solidity 0.6.7;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

import {ICurveFi} from "interfaces/curvefi/ICurveFi.sol";

import {AbstractERC20Amounts} from "./AbstractERC20Exchange.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";
import {Strings2} from "contracts/Strings2.sol";

contract CurveFiAction is AbstractERC20Amounts {
    using UniversalERC20 for IERC20;
    using Strings for uint;
    using Strings2 for address;

    ICurveFi _curve_fi;

    // mappings of token addresses to curve indexes PLUS ONE!
    // we add one to our indexes because fetching an unknown address will return 0!
    mapping(address => int128) _coins;
    mapping(address => int128) _underlying_coins;

    constructor(address curve_fi, int128 n) public {
        _curve_fi = ICurveFi(curve_fi);

        for (int128 i = 0; i < n; i++) {
            address coin = _curve_fi.coins(i);

            _coins[coin] = i + 1;

            address underlying_coin = _curve_fi.underlying_coins(i);

            _underlying_coins[underlying_coin] = i + 1;
        }
    }

    function getAmounts(address token_a, uint256 token_a_amount, address token_b)
        external view
        returns (Amount[] memory)
    {
        bytes memory extra_data = "";

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(address maker_token, uint taker_wei, address taker_token, bytes memory /* extra_data */)
        public override view
        returns (Amount memory)
    {
        Amount memory a = newPartialAmount(maker_token, taker_wei, taker_token);

        // i is the taker token
        int128 i = _coins[taker_token];
        // j is the maker token
        int128 j = _coins[maker_token];

        if (i == 0 || j == 0) {
            // at least one of the coins was not found
            int128 underlying_i = _underlying_coins[taker_token];
            int128 underlying_j = _underlying_coins[maker_token];

            if (underlying_i == 0 || underlying_j == 0) {
                // no _coin and no _underlying_coin found. cancel
                // TODO: more specific error
                string memory err;
                // TODO: better log that uses both i/j and underlying_i/j
                if (i == 0 && j == 0) {
                    err = string(abi.encodePacked("CurveFiAction.newAmount: unsupported underlying tokens ", maker_token.toString(), " and ", taker_token.toString()));
                } else if (i == 0) {
                    err = string(abi.encodePacked("CurveFiAction.newAmount: unsupported underlying taker ", taker_token.toString()));
                } else if (j == 0) {
                    err = string(abi.encodePacked("CurveFiAction.newAmount: unsupported underlying maker ", maker_token.toString()));
                }

                a.error = err;

                return a;
            }

            // now that we know we have supported underlying_coins. fix the indexes to match what CurveFi expects
            underlying_i -= 1;
            underlying_j -= 1;

            a.maker_wei = _curve_fi.get_dy_underlying(underlying_i, underlying_j, taker_wei);
            a.selector = this.tradeUnderlying.selector;
        } else {
            // both i and j are set! coins should be valid

            // now that we know we have supported coins. fix the indexes to match what CurveFi expects
            i -= 1;
            j -= 1;

            a.maker_wei = _curve_fi.get_dy(i, j, taker_wei);
            a.selector = this.trade.selector;
        }

        //a.trade_extra_data = "";
        //a.exchange_data = "";

        return a;
    }

    // trade wrapped stablecoins
    // solium-disable-next-line security/no-assign-params
    function trade(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata /*extra_data*/)
        external
        sweepLeftoverToken(msg.sender, src_token)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }

        revert("CurveFiAction.trade: wip");
    }

    // trade stablecoins
    // solium-disable-next-line security/no-assign-params
    function tradeUnderlying(
        address to,
        address src_token,
        address dest_token,
        uint dest_min_tokens,
        uint dest_max_tokens,
        bytes calldata /*extra_data*/
    )
        external
        sweepLeftoverToken(msg.sender, src_token)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }

        revert("CurveFiAction.tradeUnderlying: wip");
    }
}
