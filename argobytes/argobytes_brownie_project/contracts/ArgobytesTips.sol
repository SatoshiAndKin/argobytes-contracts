// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;
pragma abicoder v2;

import {IENS, IResolver} from "contracts/external/ens/ENS.sol";
import {IERC20} from "contracts/external/erc20/IERC20.sol";

/// @title Send tokens to an ENS name
abstract contract Tips {
    IENS constant ens = IENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    bytes32 public immutable tip_namehash;

    /// @dev we don't want to revert if tipping fails. instead we just emit an event
    event TipFailed(address indexed to, IERC20 token, uint256 amount, bytes errordata);

    constructor(bytes32 _tip_namehash) {
        tip_namehash = _tip_namehash;
    }

    /// @notice get the address for tipping from ENS
    function resolve_tip_address() internal returns (address payable) {
        IResolver resolver = ens.resolver(tip_namehash);
        return payable(resolver.addr(tip_namehash));
    }

    /// @notice send some ETH to the tip address
    function tip_eth(uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        address payable tip_address = resolve_tip_address();

        if (tip_address == address(0)) {
            emit TipFailed(tip_address, IERC20(address(0)), amount, "");
            return;
        }

        (bool success, bytes memory errordata) = tip_address.call{value: msg.value}("");

        if (!success) {
            emit TipFailed(tip_address, IERC20(address(0)), amount, errordata);
        }
    }

    /// @notice send some ERC20 tokens to the tip address
    function tip_erc20(IERC20 token, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        address tip_address = resolve_tip_address();

        if (tip_address == address(0)) {
            emit TipFailed(tip_address, token, amount, "");
            return;
        }

        // at first, we used "SafeTransfer", but we don't actually want to revert on a failing tip
        try token.transfer(tip_address, amount) {
            // don't bother checking the return bool
            // we don't want to revert on a failing tip
        } catch (bytes memory errordata) {
            emit TipFailed(tip_address, token, amount, errordata);
        }
    }
}

/// @title Send tokens to tip.satoshiandkin.eth
abstract contract ArgobytesTips is Tips {
    /// @dev `brownie.web3.ens.namehash("tip.satoshiandkin.eth")`
    constructor() Tips(0x6797569217323c160453d50601152fd4a68e66c4c1fd0bfc8a3f902fa488d465) {}
}
