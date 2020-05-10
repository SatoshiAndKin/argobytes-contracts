/* The Depot is a place to deposit any excess sUSD for others to purchase it with ETH

https://docs.synthetix.io/contracts/depot/
https://docs.synthetix.io/contracts/walkthrus/depot/
https://github.com/Synthetixio/synthetix/blob/develop/contracts/Depot.sol#L20

The depot is capable of trading SNX, too. However, that is only done on Testnets.
*/
pragma solidity 0.6.7;
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

        // TODO: use setAddresses();
        _status = ISystemStatus(_address_resolver.getAddress("SystemStatus"));
        _depot = IDepot(0xE1f64079aDa6Ef07b03982Ca34f1dD7152AA3b86);
        _sETH = 0x5e74C9036fb86BD7eCdcb084a0673EFc32eA31cb;
        _SNX = 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F;
        _sUSD = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
    }

    // this will be wrong until may 10
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
            // a.selector = this.tradeEtherToSynthUSD.selector;
        } else {
            string memory err = string(abi.encodePacked("SynthetixDepotAction.newAmount: found ", taker_token.toString(), "->", maker_token.toString(), ". supported ", ZERO_ADDRESS.toString(), "->", _sUSD.toString()));

            // revert(err);
            a.error = err;
        }

        //a.extra_data = "";

        return a;
    }

    // solium-disable-next-line security/no-assign-params
    function tradeEtherToSynthUSD(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
        external
        payable
        sweepLeftoverEther(msg.sender)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }
        
        revert("SynthetixDepotAction.tradeEtherToSynthUSD: wip");
    }
}
