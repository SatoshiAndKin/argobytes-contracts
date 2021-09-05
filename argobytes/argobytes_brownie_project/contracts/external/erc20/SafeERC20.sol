// SPDX-License-Identifier: MIT
// Based on OpenZeppelin's SafeERC20
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b0cf6fbb7a70f31527f36579ad644e1cf12fdf4e/contracts/token/ERC20/utils/SafeERC20.sol

pragma solidity 0.8.7;

import {IERC20} from "./IERC20.sol";
import {AddressLib} from "contracts/library/AddressLib.sol";

error TransferFailed(address token, bytes data);

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // if (value > 0 && token.allowance(msg.sender, spender) > 0) {
        //     // some tokens are really annoying and made a bad design desision in the name of "security"
        //     _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
        // }
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        // some ERC20s will revert here
        bytes memory returndata = AddressLib.functionCall(address(token), data);

        if (returndata.length > 0) {
            // Return data is optional. if we got back "false", revert
            if (abi.decode(returndata, (bool)) == false) {
                revert TransferFailed(address(token), data);
            }
        }
    }
}
