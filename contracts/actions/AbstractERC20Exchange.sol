/*
 * There are multitudes of possible contracts for SoloArbitrage. AbstractExchange is for interfacing with ERC20.
 * 
 * These contracts should also be written in a way that they can work with any flash lender
 * 
 * Rewrite this to use UniversalERC20? I'm not sure its worth it. this is pretty easy to follow.
 */
pragma solidity 0.6.6;

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

    // these functions require that address(this) has an ether/token balance.
    // these functions might have some leftover ETH or src_token in them after they finish, so be sure to use the sweep modifiers
    // TODO: decide on best order for the arguments
    // TODO: _tradeUniversal?
    function _tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;
    function _tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;
    function _tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;

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
