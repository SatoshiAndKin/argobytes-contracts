/*
 * There are multitudes of possible contracts for SoloArbitrage. AbstractExchange is for interfacing with ERC20.
 * 
 * These contracts should also be written in a way that they can work with any flash lender
 * 
 * Rewrite this to use UniversalERC20? I'm not sure its worth it. this is pretty easy to follow.
 */
pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import "OpenZeppelin/openzeppelin-contracts@3.0.0-rc.1/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0-rc.1/contracts/token/ERC20/SafeERC20.sol";

contract AbstractERC20ExchangeModifiers {
    using SafeERC20 for IERC20;

    // this function must be able to receive ether if it is expected to sweep it
    receive() external payable { }

    /// @dev after the function, send any remaining ether to an address
    modifier sweepLeftoverEther(address payable to) {
        _;

        uint balance = address(this).balance;

        if (balance > 0) {
            // TODO: require this succeded? or does it revert on fail?
            Address.sendValue(to, balance);
        }
    }

    /// @dev after the function, send any remaining tokens to an address
    modifier sweepLeftoverToken(address to, address token) {
        _;

        uint balance = IERC20(token).balanceOf(address(this));

        if (balance > 0) {
            IERC20(token).safeTransfer(to, balance);
        }
    }
}

abstract contract AbstractERC20Exchange is AbstractERC20ExchangeModifiers {

    // TODO: document this. i think it came from Kyber
    uint public constant MAX_QTY = 10**28;
    address public constant ZERO_ADDRESS = address(0x0);

    struct Amount {
        address maker_token;
        uint256 maker_wei;
        address taker_token;
        uint256 taker_wei;

        bytes4 selector;
        bytes call_data;
    }

    // these functions require that address(this) has an ether/token balance.
    // these functions might have some leftover ETH or src_token in them after they finish, so be sure to use the sweep modifiers
    // TODO: decide on best order for the arguments
    // TODO: _tradeUniversal?
    function _tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;
    function _tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;
    function _tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;

    // function getAmounts(address token_a, uint256 token_a_amount, address token_b, bytes calldata extra_data)
    //     external
    //     returns (Amount[] memory)
    // {
    //     require(token_a != token_b, "token_a should != token_b");

    //     Amount[] memory amounts = new Amount[](2);

    //     // get amounts for trading token_a -> token_b
    //     // use the same amounts that we used in our ETH trades to keep these all around the same value
    //     amounts[0] = newAmount(token_b, token_a_amount, token_a, extra_data);

    //     // get amounts for trading token_b -> token_a
    //     amounts[1] = newAmount(token_a, amounts[0].maker_wei, token_b, extra_data);

    //     return amounts;
    // }

    function newAmount(address maker_token, uint taker_wei, address taker_token, bytes memory extra_data)
        internal virtual view 
        returns (Amount memory);

    function newPartialAmount(address maker_token, uint taker_wei, address taker_token)
        internal pure
        returns (Amount memory)
    {
        bytes4 selector;
        if (maker_token == ZERO_ADDRESS) {
            selector = this.tradeTokenToEther.selector;
        } else if (taker_token == ZERO_ADDRESS) {
            selector = this.tradeEtherToToken.selector;
        } else {
            selector = this.tradeTokenToToken.selector;
        }

        Amount memory a = Amount({
            maker_token: maker_token,
            maker_wei: 0,
            taker_token: taker_token,
            taker_wei: taker_wei,
            selector: selector,
            call_data: ""
        });

        // missing maker_wei and call_data! you need to set these in your `newAmount`

        return a;
    }

    function tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
        external
        payable
        sweepLeftoverEther(msg.sender)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }

        _tradeEtherToToken(to, dest_token, dest_min_tokens, dest_max_tokens, extra_data);
    }

    function tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
        external
        sweepLeftoverToken(msg.sender, src_token)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }

        _tradeTokenToToken(to, src_token, dest_token, dest_min_tokens, dest_max_tokens, extra_data);
    }

    function tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
        external
        sweepLeftoverToken(msg.sender, src_token)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }

        _tradeTokenToEther(to, src_token, dest_min_tokens, dest_max_tokens, extra_data);
    }

}
