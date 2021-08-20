// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {IERC20} from "contracts/external/erc20/IERC20.sol";
import {IUniswapV2Router01} from "contracts/external/uniswap/IUniswapV2Router01.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";

contract UniswapV2Action is AbstractERC20Exchange {
    // this function must be able to receive ether if it is expected to wrap it
    receive() external payable {}

    function tradeEtherToToken(
        IUniswapV2Router01 router,
        address[] calldata path,
        uint256 dest_min_tokens,
        address to
    ) external payable {
        // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        //     external
        //     payable
        //     returns (uint[] memory amounts);
        // solium-disable-next-line security/no-block-members
        router.swapExactETHForTokens{value: address(this).balance - 1}(dest_min_tokens, path, to, block.timestamp);
    }

    function tradeTokenToToken(
        IUniswapV2Router01 router,
        address[] calldata path,
        uint256 dest_min_tokens,
        address to
    ) external {
        // leave 1 wei behind for gas savings on future calls
        uint256 src_balance = IERC20(path[0]).balanceOf(address(this)) - 1;

        // some contracts do all sorts of fancy approve from 0 checks to avoid front running issues. I really don't see the benefit here
        IERC20(path[0]).approve(address(router), src_balance);

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
        router.swapExactTokensForTokens(src_balance, dest_min_tokens, path, to, block.timestamp);
    }

    function tradeTokenToEther(
        IUniswapV2Router01 router,
        address[] calldata path,
        uint256 dest_min_tokens,
        address payable to
    ) external {
        // leave 1 wei behind for gas savings on future calls
        uint256 src_balance = IERC20(path[0]).balanceOf(address(this)) - 1;

        IERC20(path[0]).approve(address(router), src_balance);

        /*
        function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
            external
            returns (uint[] memory amounts);
        */
        // solium-disable-next-line security/no-block-members
        router.swapExactTokensForETH(src_balance, dest_min_tokens, path, to, block.timestamp);
    }
}
