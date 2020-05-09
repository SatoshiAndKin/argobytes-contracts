pragma solidity 0.6.7;
pragma experimental ABIEncoderV2;

import {SafeERC20} from "@openzeppelin/token/ERC20/SafeERC20.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {UniversalERC20, IERC20} from "contracts/UniversalERC20.sol";
import {IKyberNetworkProxy} from "interfaces/kyber/IKyberNetworkProxy.sol";

contract KyberAction is AbstractERC20Exchange {
    // TODO: we were using ERC20 instead of IERC20 because of kyber's interface. does this work?
    using UniversalERC20 for IERC20;

    // TODO: document this
    uint internal constant MAX_QTY = 10**28;

    IERC20 constant ETH_ON_KYBER = IERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

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
        require(dest_token != ZERO_ADDRESS, "KyberAction._tradeEtherToToken: dest_token cannot be ZERO_ADDRESS");
        require(IERC20(dest_token) != ETH_ON_KYBER, "KyberAction._tradeEtherToToken: dest_token cannot be ETH");

        uint src_amount = address(this).balance;

        require(src_amount > 0, "KyberAction._tradeEtherToToken: NO_SRC_AMOUNT");

        if (dest_max_tokens == 0) {
            // TODO: not sure about this anymore. i didn't document it well. where did it come from?
            dest_max_tokens = MAX_QTY;
        }

        uint received = _network_proxy.trade{value: src_amount}(
            ETH_ON_KYBER,
            src_amount,
            IERC20(dest_token),
            to,
            dest_max_tokens,
            1,  // minConversionRate of 1 will execute the trade according to market price
            _wallet_id
        );

        // TODO: use a real minConversionRate to ensure this?
        require(received >= dest_min_tokens, "KyberAction._tradeTokenToToken: FAILED_TRADE");
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
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(src_amount > 0, "KyberAction._tradeTokenToToken: NO_SOURCE_AMOUNT");

        // Approve the exchange to transfer tokens from this contract to the reserve
        require(IERC20(src_token).approve(address(_network_proxy), src_amount), "KyberAction._tradeTokenToToken: FAILED_APPROVE");

        if (dest_max_tokens == 0) {
            dest_max_tokens = MAX_QTY;
        }
        // TODO: make sure dest_max_tokens < MAX_QTY!

        uint received = _network_proxy.trade(
            IERC20(src_token),
            src_amount,
            IERC20(dest_token),
            to,
            dest_max_tokens,
            1,  // minConversionRate of 1 will execute the trade according to market price
            _wallet_id
        );

        // TODO: use a real minConversionRate to ensure this?
        require(received >= dest_min_tokens, "KyberAction._tradeTokenToToken: FAILED_TRADE");
    }

    function _tradeTokenToEther(
        address to,
        address src_token,
        uint dest_min_tokens,
        uint dest_max_tokens, 
        bytes memory
    ) internal override {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(src_amount > 0, "KyberAction._tradeTokenToEther: NO_SOURCE_AMOUNT");

        // Approve the exchange to transfer tokens from this contract to the reserve
        require(IERC20(src_token).approve(address(_network_proxy), src_amount), "KyberAction._tradeTokenToEther: FAILED_APPROVE");

        if (dest_max_tokens == 0) {
            dest_max_tokens = MAX_QTY;
        }
        // TODO: make sure dest_max_tokens < MAX_QTY!

        // TODO: maybe this should take a destination address. then we can give it to the next hop instead of back to the teller. we could even send it direct to the bank
        uint received = _network_proxy.trade(
            IERC20(src_token),
            src_amount,
            ETH_ON_KYBER,
            to,
            dest_max_tokens,
            1,  // minConversionRate of 1 will execute the trade according to market price
            _wallet_id
        );

        // TODO: use a real minConversionRate to ensure this?
        require(received >= dest_min_tokens, "KyberAction._tradeTokenToEther: FAILED_TRADE");
    }

    function getAmounts(address token_a, uint256 token_a_amount, address token_b)
        external view
        returns (Amount[] memory)
    {
        bytes memory extra_data = "";

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(address maker_token, uint taker_wei, address taker_token, bytes memory extra_data)
        public override view
        returns (Amount memory)
    {
        Amount memory a = newPartialAmount(maker_token, taker_wei, taker_token);

        uint expected_rate;

        // TODO: this only works with input amounts. do we want it to work with output amounts?
        if (maker_token == ZERO_ADDRESS) {
            // token to eth
            (expected_rate, ) = _network_proxy.getExpectedRate(IERC20(taker_token), ETH_ON_KYBER, taker_wei);
        } else if (taker_token == ZERO_ADDRESS) {
            // eth to token
            (expected_rate, ) = _network_proxy.getExpectedRate(ETH_ON_KYBER, IERC20(maker_token), taker_wei);
        } else {
            // token to token
            (expected_rate, ) = _network_proxy.getExpectedRate(IERC20(taker_token), IERC20(maker_token), taker_wei);
        }

        // TODO: disable the uniswap reserve? https://github.com/CryptoManiacsZone/1split/blob/614fa1efdd647d560491671c92869daf69f158b0/contracts/OneSplitBase.sol#L532

        uint maker_decimals = IERC20(maker_token).universalDecimals();
        uint taker_decimals = IERC20(taker_token).universalDecimals();

        // https://developer.kyber.network/docs/API_ABI-TokenQuantityConversion/#calcdstqty
        // https://github.com/KyberNetwork/smart-contracts/blob/master/contracts/Utils2.sol#L28
        uint precision = 10 ** 18;

        // TODO: i think this is on Kyber's Utils2 contract. use that instead
        // 
        if (maker_decimals >= taker_decimals) {
            // (srcQty * rate * (10**(dstDecimals - srcDecimals))) / PRECISION;
            expected_rate = (taker_wei * expected_rate * (10 ** (maker_decimals - taker_decimals))) / precision;
        } else {
            // (srcQty * rate) / (PRECISION * (10**(srcDecimals - dstDecimals)));
            expected_rate = (taker_wei * expected_rate) / (precision * (10 ** (taker_decimals - maker_decimals)));
        }

        // TODO: use slippage_rate?
        a.maker_wei = expected_rate;
        //a.extra_data = "";

        return a;
    }
}
