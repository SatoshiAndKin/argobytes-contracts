// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.4;

import {IERC20} from "contracts/library/UniversalERC20.sol";
import {
    IUniswapV2Router02
} from "contracts/external/uniswap/IUniswapV2Router02.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";

contract UniswapV2Action is AbstractERC20Exchange {

    /*
    // we don't need this. just use router.swapExactETHForTokens as your action
    function tradeEtherToToken(
        address to,
        address router,
        address[] calldata path,
        uint256 dest_min_tokens
    ) external payable {
        // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        //     external
        //     payable
        //     returns (uint[] memory amounts);
        // solium-disable-next-line security/no-block-members
        IUniswapV2Router02(router).swapExactETHForTokens{
            value: address(this).balance
        }(dest_min_tokens, path, to, block.timestamp);
    }
    */

    function tradeTokenToToken(
        address to,
        address router,
        address[] calldata path,
        uint256 dest_min_tokens
    ) external {
        uint256 src_balance = IERC20(path[0]).balanceOf(address(this));

        // some contracts do all sorts of fancy approve from 0 checks to avoid front running issues. I really don't see the benefit here
        IERC20(path[0]).approve(router, src_balance);

        /*
        function swapExactTokensForTokens(
            uint amountIn,
            uint amountOutMin,
            address[] calldata path,
            address to,
            uint deadline
        ) external returns (uint[] memory amounts);
        */
        // solium-disable-next-line security/no-block-members
        IUniswapV2Router02(router).swapExactTokensForTokens(
            src_balance,
            dest_min_tokens,
            path,
            to,
            block.timestamp
        );
    }

    function tradeTokenToEther(
        address payable to,
        address router,
        address[] calldata path,
        uint256 dest_min_tokens
    ) external {
        uint256 src_balance = IERC20(path[0]).balanceOf(address(this));

        IERC20(path[0]).approve(router, src_balance);

        /*
        function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
            external
            returns (uint[] memory amounts);
        */
        // solium-disable-next-line security/no-block-members
        IUniswapV2Router02(router).swapExactTokensForETH(
            src_balance,
            dest_min_tokens,
            path,
            to,
            block.timestamp
        );
    }
}
