/* if possible, you should use the network proxy directly */
// TODO: do we want auth on this with setters? i think no. i think we should just have a simple contract with a constructor. if we need changes, we can deploy a new contract. less methods is less attack surface

pragma solidity 0.6.6;

import "OpenZeppelin/openzeppelin-contracts@3.0.0-rc.1/contracts/token/ERC20/ERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0-rc.1/contracts/token/ERC20/SafeERC20.sol";

import "contracts/UniversalERC20.sol";
import "./AbstractERC20Exchange.sol";
import "interfaces/kyber/IKyberNetworkProxy.sol";

contract KyberAction is AbstractERC20Exchange {
    // TODO: stuck using ERC20 instead of IERC20 because of kyber's interface. can we rename during importing?
    using UniversalERC20 for ERC20;

    ERC20 constant internal ETH_ON_KYBER = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

    IKyberNetworkProxy _network_proxy;
    address _wallet_id;

    constructor(address network_proxy, address wallet_id) public {
        _network_proxy = IKyberNetworkProxy(network_proxy);

        // TODO: setter for _wallet_id
        _wallet_id = wallet_id;
    }

    function _tradeEtherToToken(
        address to,
        address dest_token,
        uint dest_min_tokens,
        uint dest_max_tokens, 
        bytes memory
    ) internal override {
        uint src_amount = address(this).balance;

        require(src_amount > 0, "NO_ETH");

        if (dest_max_tokens == 0) {
            // TODO: not sure about this anymore. i didn't document it well. where did it come from?
            dest_max_tokens = MAX_QTY;
        }

        uint received = _network_proxy.trade{value: src_amount}(
            ETH_ON_KYBER,
            src_amount,
            ERC20(dest_token),
            to,
            dest_max_tokens,
            1,  // minConversionRate of 1 will execute the trade according to market price
            _wallet_id
        );

        // TODO: use a real minConversionRate to ensure this?
        require(received >= dest_min_tokens, "BAD_ETH_TO_TOKEN");
    }

    function _tradeTokenToToken(
        address to,
        address src_token,
        address dest_token,
        uint dest_min_tokens,
        uint dest_max_tokens, 
        bytes memory
    ) internal override {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = ERC20(src_token).balanceOf(address(this));
        require(src_amount > 0, "NO_TOKENS");

        if (ERC20(src_token).allowance(address(this), address(_network_proxy)) < src_amount) {
            // Approve the exchange to transfer tokens from this contract to the reserve
            ERC20(src_token).approve(address(_network_proxy), src_amount);
        }

        if (dest_max_tokens == 0) {
            dest_max_tokens = MAX_QTY;
        }
        // TODO: make sure dest_max_tokens < MAX_QTY!

        uint received = _network_proxy.trade(
            ERC20(src_token),
            src_amount,
            ERC20(dest_token),
            to,
            dest_max_tokens,
            1,  // minConversionRate of 1 will execute the trade according to market price
            _wallet_id
        );

        // TODO: use a real minConversionRate to ensure this?
        require(received >= dest_min_tokens, "BAD_ERC20_TO_ERC20");
    }

    function _tradeTokenToEther(
        address to,
        address src_token,
        uint dest_min_tokens,
        uint dest_max_tokens, 
        bytes memory
    ) internal override {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = ERC20(src_token).balanceOf(address(this));
        require(src_amount > 0, "NO_TOKENS");

        if (ERC20(src_token).allowance(address(this), address(_network_proxy)) < src_amount) {
            // Approve the exchange to transfer tokens from this contract to the reserve
            // TODO: only approve what is necessary? approve VERY_LARGE_INT?
            ERC20(src_token).approve(address(_network_proxy), src_amount);
        }

        if (dest_max_tokens == 0) {
            dest_max_tokens = MAX_QTY;
        }
        // TODO: make sure dest_max_tokens < MAX_QTY!

        // TODO: maybe this should take a destination address. then we can give it to the next hop instead of back to the teller. we could even send it direct to the bank
        uint received = _network_proxy.trade(
            ERC20(src_token),
            src_amount,
            ETH_ON_KYBER,
            to,
            dest_max_tokens,
            1,  // minConversionRate of 1 will execute the trade according to market price
            _wallet_id
        );

        // TODO: use a real minConversionRate to ensure this?
        require(received >= dest_min_tokens, "BAD_ERC20_TO_ERC20");
    }

}
