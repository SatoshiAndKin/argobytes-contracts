// i can't figure out how to access interfaces as pytest fixtures, so i wrote this

// brownie dev said he would support interfaces as fixtures soon. that means we shouldn't need this for long
pragma solidity 0.6.6;

import "interfaces/weth9/IWETH9.sol";

contract QuickAndDirty {

    IWETH9 public _weth9 = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // this function must be able to receive ether if it is expected to wrap it
    receive() external payable { }

    function weth9_balanceOf(address who) external returns (uint256) {
        return _weth9.balanceOf(who);
    }

    function weth9_transfer(address dst, uint256 wad) external returns (bool) {
        return _weth9.transfer(dst, wad);
    }
}
