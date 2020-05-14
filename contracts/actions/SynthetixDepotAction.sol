/* The Depot is a place to deposit any excess sUSD for others to purchase it with ETH

https://docs.synthetix.io/contracts/depot/
https://docs.synthetix.io/contracts/walkthrus/depot/
https://github.com/Synthetixio/synthetix/blob/develop/contracts/Depot.sol#L20

The depot is capable of trading SNX, too. However, that is only done on Testnets.
*/
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

import {IDepot} from "interfaces/synthetix/IDepot.sol";
import {IAddressResolver} from "interfaces/synthetix/IAddressResolver.sol";
import {ISystemStatus} from "interfaces/synthetix/ISystemStatus.sol";

import {AbstractERC20Amounts} from "./AbstractERC20Exchange.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";
import {Strings2} from "contracts/Strings2.sol";

contract SynthetixDepotAction is AbstractERC20Amounts {
    using UniversalERC20 for IERC20;
    using Strings for uint;
    using Strings2 for address;

    IAddressResolver _address_resolver;
    ISystemStatus _status;
    IDepot _depot;
    address _sETH;
    address _SNX;
    address _sUSD;

    constructor(address address_resolver) public {
        // https://docs.synthetix.io/contracts/AddressResolver
        _address_resolver = IAddressResolver(address_resolver);

        setAddresses();
    }

    function setAddresses() public {
        _depot = IDepot(_address_resolver.getAddress("Depot"));
        _status = ISystemStatus(_address_resolver.getAddress("SystemStatus"));
        _sETH = _address_resolver.getAddress("SynthsETH");
        _SNX = _address_resolver.getAddress("Synthetix");
        _sUSD = _address_resolver.getAddress("SynthsUSD");
    }

    function getAmounts(address token_a, uint256 token_a_amount, address token_b)
        external view
        returns (Amount[] memory)
    {
        bytes memory extra_data = "";

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(address maker_token, uint taker_wei, address taker_token, bytes memory /* extra_data */)
        public override view
        returns (Amount memory)
    {
        Amount memory a = newPartialAmount(maker_token, taker_wei, taker_token);

        if (taker_token == ZERO_ADDRESS && maker_token == _sUSD) {
            // eth to sUSD

            _status.requireSynthActive("SynthsUSD");

            a.maker_wei = _depot.synthsReceivedForEther(taker_wei);
            a.selector = this.tradeEtherToSynthUSD.selector;
        } else {
            string memory err = string(abi.encodePacked("SynthetixDepotAction.newAmount: found ", taker_token.toString(), "->", maker_token.toString(), ". supported ", ZERO_ADDRESS.toString(), "->", _sUSD.toString()));

            // revert(err);
            a.error = err;
        }

        //a.trade_extra_data = "";

        return a;
    }

    // solium-disable-next-line security/no-assign-params
    // TODO: i don't think we need dest_token at all. the caller could just encode based on the selector!
    function tradeEtherToSynthUSD(address to, uint dest_min_tokens)
        external
        payable
        sweepLeftoverEther(msg.sender)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }

        uint src_balance = address(this).balance;

        _depot.exchangeEtherForSynths{value: src_balance}();

        uint dest_balance = IERC20(_sUSD).balanceOf(address(this));

        require(IERC20(_sUSD).transfer(to, dest_balance), "SynthetixDepotAction.tradeEtherToSynthUSD: transfer failed");
    }
}
