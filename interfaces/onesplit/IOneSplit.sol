pragma solidity ^0.6.6;

import "OpenZeppelin/openzeppelin-contracts@3.0.0-rc.1/contracts/token/ERC20/IERC20.sol";

abstract contract IOneSplitView {
    // disableFlags = FLAG_DISABLE_UNISWAP + FLAG_DISABLE_KYBER + ...
    uint256 public constant FLAG_DISABLE_UNISWAP = 0x01;
    uint256 public constant FLAG_DISABLE_KYBER = 0x02;
    uint256 public constant FLAG_ENABLE_KYBER_UNISWAP_RESERVE = 0x100000000; // Turned off by default
    uint256 public constant FLAG_ENABLE_KYBER_OASIS_RESERVE = 0x200000000; // Turned off by default
    uint256 public constant FLAG_ENABLE_KYBER_BANCOR_RESERVE = 0x400000000; // Turned off by default
    uint256 public constant FLAG_DISABLE_BANCOR = 0x04;
    uint256 public constant FLAG_DISABLE_OASIS = 0x08;
    uint256 public constant FLAG_DISABLE_COMPOUND = 0x10;
    uint256 public constant FLAG_DISABLE_FULCRUM = 0x20;
    uint256 public constant FLAG_DISABLE_CHAI = 0x40;
    uint256 public constant FLAG_DISABLE_AAVE = 0x80;
    uint256 public constant FLAG_DISABLE_SMART_TOKEN = 0x100;
    uint256 public constant FLAG_ENABLE_MULTI_PATH_ETH = 0x200; // Turned off by default
    uint256 public constant FLAG_DISABLE_BDAI = 0x400;
    uint256 public constant FLAG_DISABLE_IEARN = 0x800;
    uint256 public constant FLAG_DISABLE_CURVE_COMPOUND = 0x1000;
    uint256 public constant FLAG_DISABLE_CURVE_USDT = 0x2000;
    uint256 public constant FLAG_DISABLE_CURVE_Y = 0x4000;
    uint256 public constant FLAG_DISABLE_CURVE_BINANCE = 0x8000;
    uint256 public constant FLAG_ENABLE_MULTI_PATH_DAI = 0x10000; // Turned off by default
    uint256 public constant FLAG_ENABLE_MULTI_PATH_USDC = 0x20000; // Turned off by default
    uint256 public constant FLAG_DISABLE_CURVE_SYNTHETIX = 0x40000;
    uint256 public constant FLAG_DISABLE_WETH = 0x80000;

    function getExpectedReturn(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 parts,
        uint256 disableFlags // 1 - Uniswap, 2 - Kyber, 4 - Bancor, 8 - Oasis, 16 - Compound, 32 - Fulcrum, 64 - Chai, 128 - Aave, 256 - SmartToken, 1024 - bDAI
    )
        public
        virtual
        view
        returns(
            uint256 returnAmount,
            uint256[] memory distribution // [Uniswap, Kyber, Bancor, Oasis]
        );
}

abstract contract IOneSplit is IOneSplitView {
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution, // [Uniswap, Kyber, Bancor, Oasis]
        uint256 disableFlags // 16 - Compound, 32 - Fulcrum, 64 - Chai, 128 - Aave, 256 - SmartToken, 1024 - bDAI
    ) public payable virtual;

    function goodSwap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 minReturn,
        uint256 parts,
        uint256 disableFlags // 1 - Uniswap, 2 - Kyber, 4 - Bancor, 8 - Oasis, 16 - Compound, 32 - Fulcrum, 64 - Chai, 128 - Aave, 256 - SmartToken, 1024 - bDAI
    ) public payable virtual;
}
