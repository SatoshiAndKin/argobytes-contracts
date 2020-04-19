pragma solidity 0.6.6;

import "./AbstractERC20Exchange.sol";
import "interfaces/uniswap/IUniswapFactory.sol";
import "interfaces/uniswap/IUniswapExchange.sol";

// TODO: do we want auth on this with setters? i think no. i think we should just have a simple contract with a constructor. if we need changes, we can deploy a new contract. less methods is less attack surface
contract UniswapAction is AbstractERC20Exchange {

    IUniswapFactory uniswapFactory;

    constructor(address _factoryAddress) public {
        // TODO: gas may be cheaper if we pass this as an argument on each call instead of retrieving from storage
        uniswapFactory = IUniswapFactory(_factoryAddress);
    }

    function getExchange(address _token) public view returns(IUniswapExchange) {
        return IUniswapExchange(uniswapFactory.getExchange(_token));
    }

    // TODO: helper here that sets allowances and then transfers? i think IUniswapExchange might already have all the methods we need though
    function _tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory) internal override {
        uint srcBalance = address(this).balance;

        require(srcBalance > 0, "NO_BALANCE");

        IUniswapExchange exchange = getExchange(dest_token);
        require(address(exchange) != address(0), "NO_EXCHANGE");

        if (dest_max_tokens > 0) {
            require(dest_min_tokens == 0, "SET_MIN_OR_MAX");  // TODO: do something with dest_min_tokens?

            // def ethToTokenTransferOutput(tokens_bought: uint256, deadline: timestamp, recipient: address) -> uint256(wei):
            // solium-disable-next-line security/no-block-members
            require(exchange.ethToTokenTransferOutput{value: srcBalance}(dest_max_tokens, block.timestamp, to) > 0, "BAD_EXCHANGE");
        // TODO: should this "else" be "else if (dest_min_tokens > 0)"? less gas to just use an else. who cares if they passed 0 for dest_min_tokens. maybe slippage doesn't matter for their use
        } else {
            // dest_max_tokens is 0
            // dest_min_tokens may be 0, but is probably set to something to protect against large slippage in price

            // def ethToTokenTransferInput(min_tokens: uint256, deadline: timestamp, recipient: address) -> uint256
            // solium-disable-next-line security/no-block-members
            require(exchange.ethToTokenTransferInput{value: srcBalance}(dest_min_tokens, block.timestamp, to) > 0, "BAD_EXCHANGE");
        }

        // TODO: i don't think this revert is necessary
        // } else {
        //     revert("INVALID_TRADE");
        // }

    }

    function _tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory) internal override {
        to;
        src_token;
        dest_token;
        dest_min_tokens;
        dest_max_tokens;
        revert("wip");
    }

    function _tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory) internal override {
        uint srcBalance = IERC20(src_token).balanceOf(address(this));
        require(srcBalance > 0, "NO_BALANCE");

        IUniswapExchange exchange = getExchange(src_token);
        require(address(exchange) != address(0), "NO_EXCHANGE");

        // TODO: require on this
        IERC20(src_token).approve(address(exchange), srcBalance);

        if (dest_max_tokens > 0) {
            require(dest_min_tokens == 0, "SET_MIN_OR_MAX");  // TODO: do something with dest_min_tokens?

            // def tokenToEthTransferOutput(eth_bought: uint256(wei), max_tokens: uint256, deadline: timestamp, recipient: address) -> uint256:
            // solium-disable-next-line security/no-block-members
            require(exchange.tokenToEthTransferOutput(dest_max_tokens, srcBalance, block.timestamp, to) > 0, "BAD_EXCHANGE");
        } else {
            // dest_max_tokens is 0
            // dest_min_tokens may be 0, but is probably set to something to protect against large slippage in price

            // def tokenToEthTransferInput(tokens_sold: uint256, min_eth: uint256(wei), deadline: timestamp, recipient: address) -> uint256(wei):
            // solium-disable-next-line security/no-block-members
            require(exchange.tokenToEthTransferInput(srcBalance, dest_min_tokens, block.timestamp, to) > 0, "BAD_EXCHANGE");
        }
    }
}
