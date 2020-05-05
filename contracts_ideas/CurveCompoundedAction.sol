// https://github.com/curvefi/curve-contract/blob/compounded/integrations.md

pragma solidity 0.6.4;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {ICurveCompounded} from "interfaces/curve/ICurveCompounded.sol";


contract CurveCompoundedAction is AbstractERC20ExchangeModifiers {
    int128 public constant DAI_ID = 0;
    int128 public constant USDC_ID = 1;

    ICurveCompounded exchange;

    // tokenToToken will need to inspect curve's coins to know the right action to take
    // instead, lets just make functions specific for each trade type

    // function _tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens) internal override {

    function tradeCDAItoCUSDC(address to, uint256 dest_min_tokens) external {
        // def exchange(i: int128, j: int128, dx: uint256, min_dy: uint256, deadline: timestamp):

        revert("wip");

        // TODO: sweep any leftovers!
    }

    // function tradeDAItoUSDC() external {
    //     revert("wip");
    // }

    // function tradeCUSDCtoCDAI() external {
    //     revert("wip");
    // }

    // function tradeUSDCtoDAI() external {
    //     revert("wip");
    // }
}
