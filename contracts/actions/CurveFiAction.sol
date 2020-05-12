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

        bool trade_underlying = false;
        // j is the maker token
        int128 j = _coins[maker_token];
        // i is the taker token
        int128 i = 0;

        if (j == 0) {
            // no _coin was found. try _underlying_coins

            j = _underlying_coins[maker_token];

            if (j == 0) {
                // no _coin and no _underlying_coin found. cancel
                string memory err = string(abi.encodePacked("CurveFiAction.newAmount: unsupported maker token ", maker_token.toString()));

                a.error = err;

                return a;
            }

            // we have a support maker token. now check the taker
            trade_underlying = true;

            i = _underlying_coins[taker_token];

            if (i == 0) {
                string memory err = string(abi.encodePacked("CurveFiAction.newAmount: unsupported underlying taker token ", taker_token.toString()));

                a.error = err;

                return a;
            }
        } else {
            i = _coins[taker_token];

            if (i == 0) {
                string memory err = string(abi.encodePacked("CurveFiAction.newAmount: unsupported taker token ", taker_token.toString()));

                a.error = err;

                return a;
            }
        }

        // now that we know we have supported tokens. fix the indexes to match what CurveFi expects
        j -= 1;
        i -= 1;

        if (trade_underlying) {
            a.maker_wei = _curve_fi.get_dy_underlying(i, j, taker_wei);
            // a.selector = this.tradeUnderlying.selector
        } else {
            a.maker_wei = _curve_fi.get_dy(i, j, taker_wei);
            // a.selector = this.trade.selector
        }

        //a.trade_extra_data = "";

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
