pragma solidity 0.6.6;

import {IWETH9} from "interfaces/weth9/IWETH9.sol";


// TODO: do we want auth on this with setters? i think no. i think we should just have a simple contract with a constructor. if we need changes, we can deploy a new contract. less methods is less attack surface
contract Weth9Action {
    // cheaper as calldata or saved on the contract? i assume saved is cheaper
    IWETH9 public _WETH9;

    constructor(address weth9) public {
        // TODO: gas may be cheaper if we pass this as an argument on each call instead of retrieving from storage
        _WETH9 = IWETH9(weth9);
    }

    // this function must be able to receive ether if it is expected to wrap it
    receive() external payable { }

    // there is no need for sweepLeftoverEther. this will always convert everything
    function wrap_all_to(address to)
        external
        payable
    {
        uint256 balance = address(this).balance;

        require(balance > 0, "Weth9Action:wrap_all_to: no balance");

        // convert all ETH into WETH
        _WETH9.deposit{value: balance}();

        // send WETH to the next contract
        require(_WETH9.transfer(to, balance), "Weth9Action.wrap_all_to: transfer failed");
    }

    // there is no need for sweepLeftoverToken. this will always convert everything
    function unwrap_all_to(address payable to)
        external
    {
        uint256 balance = _WETH9.balanceOf(address(this));

        require(balance > 0, "Weth9Action:unwrap_all_to: no balance");

        // convert all WETH into ETH
        _WETH9.withdraw(balance);

        // send ETH to the next contract
        require(to.send(balance), "Weth9Action.unwrap_all_to: send failed");
    }
}
