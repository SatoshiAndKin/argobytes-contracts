// SPDX-License-Identifier: LGPL-3.0-or-later
// https://github.com/CryptoManiacsZone/1split/blob/014d4a08ef746af4b4da053e9465927d151ec1fe/contracts/UniversalERC20.sol
// this is probably going to cost more gas than doing this all in Rust, but this is saving me a lot of time
// make it work, make it work right, make it work fast. gas counts as "fast"
pragma solidity 0.6.8;

import {SafeMath} from "@openzeppelin/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/SafeERC20.sol";


library UniversalERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 private constant ADDRESS_ZERO = IERC20(0x0000000000000000000000000000000000000000);
    IERC20 private constant ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function universalTransfer(IERC20 token, address to, uint256 amount) internal returns(bool) {
        if (amount == 0) {
            return true;
        }

        if (isETH(token)) {
            // https://diligence.consensys.net/blog/2019/09/stop-using-soliditys-transfer-now/
            (bool success, ) = to.call{value: amount}("");
            require(success, "UniversalERC20.universalTransfer: ETH transfer failed");
        } else {
            token.safeTransfer(to, amount);
            return true;
        }
    }

    function universalTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        if (isETH(token)) {
            require(from == msg.sender && msg.value >= amount, "Wrong useage of ETH.universalTransferFrom()");
            // send ETH to "to"
            if (to != address(this)) {
                // https://diligence.consensys.net/blog/2019/09/stop-using-soliditys-transfer-now/
                (bool success, ) = to.call{value: amount}("");
                require(success, "UniversalERC20.universalTransferFrom: ETH transfer failed");
            }
            // send back any extra msg.value
            if (msg.value > amount) {
                // https://diligence.consensys.net/blog/2019/09/stop-using-soliditys-transfer-now/
                (bool success, ) = msg.sender.call{value: msg.value.sub(amount)}("");
                require(success, "UniversalERC20.universalTransferFrom: ETH refund failed");
            }
        } else {
            token.safeTransferFrom(from, to, amount);
        }
    }

    function universalTransferFromSenderToThis(IERC20 token, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        if (isETH(token)) {
            // ETH transfers are done with msg.value and so it's probably already done
            // TODO: should we revert if msg.value < amount?
            if (msg.value > amount) {
                // send back any extra msg.value
                (bool success, ) = msg.sender.call{value: msg.value.sub(amount)}("");
                require(success, "UniversalERC20: universalTransferFromSenderToThis failed");
            }
        } else {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function universalApprove(IERC20 token, address to, uint256 amount) internal {
        if (isETH(token)) { 
            // ETH doesn't need approvals
            return;
        }

        // clear the allowance if once exists
        if (amount > 0 && token.allowance(address(this), to) > 0) {
            token.safeApprove(to, 0);
        }

        // set the new allowance
        token.safeApprove(to, amount);
    }

    function universalBalanceOf(IERC20 token, address who) internal view returns (uint256) {
        if (isETH(token)) {
            return who.balance;
        } else {
            return token.balanceOf(who);
        }
    }

    function universalDecimals(IERC20 token) internal view returns (uint256) {
        if (isETH(token)) {
            return 18;
        }

        (bool success, bytes memory data) = address(token).staticcall{gas: 10000}(
            abi.encodeWithSignature("decimals()")
        );
        if (!success) {
            (success, data) = address(token).staticcall{gas: 10000}(
                abi.encodeWithSignature("DECIMALS()")
            );
        }

        return success ? abi.decode(data, (uint256)) : 18;
    }

    function isETH(IERC20 token) internal pure returns(bool) {
        return (address(token) == address(ADDRESS_ZERO) || address(token) == address(ETH_ADDRESS));
    }
}
