// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;

contract IOneSplitConsts {
    // flags = FLAG_DISABLE_UNISWAP + FLAG_DISABLE_KYBER + ...
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
    uint256 public constant FLAG_ENABLE_UNISWAP_COMPOUND = 0x100000; // Works only when one of assets is ETH or FLAG_ENABLE_MULTI_PATH_ETH
    uint256 public constant FLAG_ENABLE_UNISWAP_CHAI = 0x200000; // Works only when ETH<>DAI or FLAG_ENABLE_MULTI_PATH_ETH
    uint256 public constant FLAG_ENABLE_UNISWAP_AAVE = 0x400000; // Works only when one of assets is ETH or FLAG_ENABLE_MULTI_PATH_ETH
    uint256 public constant FLAG_DISABLE_IDLE = 0x800000;
    uint256 public constant FLAG_DISABLE_MOONISWAP = 0x1000000;
    uint256 public constant FLAG_DISABLE_UNISWAP_V2_ALL = 0x1E000000;
    uint256 public constant FLAG_DISABLE_UNISWAP_V2 = 0x2000000;
    uint256 public constant FLAG_DISABLE_UNISWAP_V2_ETH = 0x4000000;
    uint256 public constant FLAG_DISABLE_UNISWAP_V2_DAI = 0x8000000;
    uint256 public constant FLAG_DISABLE_UNISWAP_V2_USDC = 0x10000000;
    uint256 public constant FLAG_DISABLE_ALL_SPLIT_SOURCES = 0x20000000;
    uint256 public constant FLAG_DISABLE_ALL_WRAP_SOURCES = 0x40000000;
    uint256 public constant FLAG_DISABLE_CURVE_PAX = 0x80000000;
    uint256 public constant FLAG_DISABLE_CURVE_RENBTC = 0x100000000;
    uint256 public constant FLAG_DISABLE_CURVE_TBTC = 0x200000000;
    uint256 public constant FLAG_ENABLE_MULTI_PATH_USDT = 0x400000000; // Turned off by default
    uint256 public constant FLAG_ENABLE_MULTI_PATH_WBTC = 0x800000000; // Turned off by default
    uint256 public constant FLAG_ENABLE_MULTI_PATH_TBTC = 0x1000000000; // Turned off by default
    uint256 public constant FLAG_ENABLE_MULTI_PATH_RENBTC = 0x2000000000; // Turned off by default
    uint256 public constant FLAG_DISABLE_DFORCE_SWAP = 0x4000000000;
    uint256 public constant FLAG_DISABLE_SHELL = 0x8000000000;
    uint256 public constant FLAG_ENABLE_CHI_BURN = 0x10000000000;
    uint256 public constant FLAG_ENABLE_GST2_BURN = 0x20000000000;
}

abstract contract IOneSplit is IOneSplitConsts {
    function getExpectedReturn(
        address fromToken,
        address toToken,
        uint256 amount,
        uint256 parts,
        uint256 disableFlags
    ) public view virtual returns (uint256 returnAmount, uint256[] memory distribution);

    function swap(
        address fromToken,
        address toToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256 disableFlags
    ) public payable virtual;
}
