pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import "./AbstractERC20Exchange.sol";
import "interfaces/uniswap/IUniswapFactory.sol";
import "interfaces/uniswap/IUniswapExchange.sol";

// TODO: do we want auth on this with setters? i think no. i think we should just have a simple contract with a constructor. if we need changes, we can deploy a new contract. less methods is less attack surface
contract UniswapAction is AbstractERC20Exchange {

    // TODO: allow trading outside of this factory
    IUniswapFactory uniswapFactory;

    constructor(address _factoryAddress) public {
        // TODO: gas may be cheaper if we pass this as an argument on each call instead of retrieving from storage
        uniswapFactory = IUniswapFactory(_factoryAddress);
    }

    function getExchange(address _token) internal view returns(IUniswapExchange) {
        return IUniswapExchange(uniswapFactory.getExchange(_token));
    }

    // TODO: helper here that sets allowances and then transfers? i think IUniswapExchange might already have all the methods we need though
    function _tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory) internal override {
        require(dest_token != address(0x0), "UniswapAction._tradeEtherToToken: dest_token cannot be ETH");

        uint srcBalance = address(this).balance;

        require(srcBalance > 0, "UniswapAction._tradeEtherToToken: NO_BALANCE");

        IUniswapExchange exchange = getExchange(dest_token);
        require(address(exchange) != address(0), "UniswapAction._tradeEtherToToken: NO_EXCHANGE");

        if (dest_max_tokens > 0) {
            require(dest_min_tokens == 0, "UniswapAction._tradeEtherToToken: SET_MIN_OR_MAX");  // TODO: do something with dest_min_tokens?

            // def ethToTokenTransferOutput(tokens_bought: uint256, deadline: timestamp, recipient: address) -> uint256(wei):
            // solium-disable-next-line security/no-block-members
            uint received = exchange.ethToTokenTransferOutput{value: srcBalance}(dest_max_tokens, block.timestamp, to);

            require(received > 0, "UniswapAction._tradeEtherToToken: BAD_EXCHANGE");
        // TODO: should this "else" be "else if (dest_min_tokens > 0)"? less gas to just use an else. who cares if they passed 0 for dest_min_tokens. maybe slippage doesn't matter for their use
        } else {
            // dest_max_tokens is 0
            // dest_min_tokens may be 1, but is probably set to something to protect against large slippage in price
            require(dest_min_tokens > 0, "UniswapAction._tradeEtherToToken: dest_min_tokens should not == 0");

            // def ethToTokenTransferInput(min_tokens: uint256, deadline: timestamp, recipient: address) -> uint256
            // solium-disable-next-line security/no-block-members
            uint received = exchange.ethToTokenTransferInput{value: srcBalance}(dest_min_tokens, block.timestamp, to);

            require(received > 0, "UniswapAction._tradeEtherToToken: BAD_EXCHANGE");
        }
    }

    function _tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory) internal override {
        require(src_token != address(0x0), "UniswapAction._tradeTokenToToken: src_token cannot be ETH");
        require(dest_token != address(0x0), "UniswapAction._tradeTokenToToken: dest_token cannot be ETH");

        uint src_balance = IERC20(src_token).balanceOf(address(this));
        require(src_balance > 0, "UniswapAction._tradeTokenToToken: NO_BALANCE");

        IUniswapExchange exchange = getExchange(src_token);
        require(address(exchange) != address(0), "UniswapAction._tradeTokenToToken: NO_EXCHANGE");

        // TODO: require on this
        IERC20(src_token).approve(address(exchange), src_balance);

        if (dest_max_tokens > 0) {
            require(dest_min_tokens == 0, "UniswapAction._tradeTokenToToken: SET_MIN_OR_MAX");  // TODO: do something with dest_min_tokens instead?

            // TODO: how should we calculate this? tokenToEthSomething? or is it fine to use a very large amount?
            // TODO: gas golf this
            uint max_eth_sold = MAX_QTY;

            // tokenToTokenTransferOutput(
            //     tokens_bought: uint256,
            //     max_tokens_sold: uint256,
            //     max_eth_sold: uint256,
            //     deadline: uint256,
            //     recipient: address,
            //     token_addr: address
            // ): uint256
            // solium-disable-next-line security/no-block-members
            uint received = exchange.tokenToTokenTransferOutput(dest_max_tokens, src_balance, max_eth_sold, block.timestamp, to, dest_token);

            require(received > 0, "UniswapAction._tradeTokenToToken: BAD_EXCHANGE");
        } else {
            // dest_max_tokens is 0
            // dest_min_tokens may be 1, but is probably set to something to protect against large slippage in price
            require(dest_min_tokens > 0, "UniswapAction._tradeTokenToToken: dest_min_tokens should not == 0");

            // TODO: how should we calculate this? tokenToEthSomething? or is it fine to use 1
            uint min_eth_bought = 1;

            // tokenToTokenTransferInput(
            //     tokens_sold: uint256,
            //     min_tokens_bought: uint256,
            //     min_eth_bought: uint256,
            //     deadline: uint256,
            //     recipient: address
            //     token_addr: address
            // ): uint256
            // solium-disable-next-line security/no-block-members
            uint received = exchange.tokenToTokenTransferInput(src_balance, dest_min_tokens, min_eth_bought, block.timestamp, to, dest_token);

            require(received > 0, "UniswapAction._tradeTokenToToken: BAD_EXCHANGE");
        }
    }

    function _tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory) internal override {
        require(src_token != address(0x0), "UniswapAction._tradeTokenToEther: src_token cannot be ETH");

        uint srcBalance = IERC20(src_token).balanceOf(address(this));
        require(srcBalance > 0, "UniswapAction._tradeTokenToEther: NO_BALANCE");

        IUniswapExchange exchange = getExchange(src_token);
        require(address(exchange) != address(0), "UniswapAction._tradeTokenToEther: NO_EXCHANGE");

        // TODO: require on this
        IERC20(src_token).approve(address(exchange), srcBalance);

        if (dest_max_tokens > 0) {
            require(dest_min_tokens == 0, "UniswapAction._tradeTokenToEther: SET_MIN_OR_MAX");  // TODO: do something with dest_min_tokens?

            // def tokenToEthTransferOutput(eth_bought: uint256(wei), max_tokens: uint256, deadline: timestamp, recipient: address) -> uint256:
            // solium-disable-next-line security/no-block-members
            uint received = exchange.tokenToEthTransferOutput(dest_max_tokens, srcBalance, block.timestamp, to);

            require(received > 0, "UniswapAction._tradeTokenToEther: BAD_EXCHANGE");
        } else {
            // dest_max_tokens is 0
            // dest_min_tokens may be 1, but is probably set to something to protect against large slippage in price
            require(dest_min_tokens > 0, "UniswapAction._tradeTokenToEther: dest_min_tokens should not == 0");

            // def tokenToEthTransferInput(tokens_sold: uint256, min_eth: uint256(wei), deadline: timestamp, recipient: address) -> uint256(wei):
            // solium-disable-next-line security/no-block-members
            uint received = exchange.tokenToEthTransferInput(srcBalance, dest_min_tokens, block.timestamp, to);

            require(received > 0, "UniswapAction._tradeTokenToEther: BAD_EXCHANGE");
        }
    }

    function getAmounts(address token_a, uint256 token_a_amount, address token_b, bytes calldata extra_data)
        external
        returns (Amount[] memory)
    {
        require(token_a != token_b, "token_a should != token_b");

        Amount[] memory amounts = new Amount[](2);

        // get amounts for trading token_a -> token_b
        // use the same amounts that we used in our ETH trades to keep these all around the same value
        amounts[0] = newAmount(token_b, token_a_amount, token_a, extra_data);

        // get amounts for trading token_b -> token_a
        amounts[1] = newAmount(token_a, amounts[0].maker_wei, token_b, extra_data);

        return amounts;
    }

    function newAmount(address maker_address, uint taker_wei, address taker_address, bytes memory extra_data)
        internal override view 
        returns (Amount memory)
    {
        revert("wip");
    }
}
