// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.6;

// TODO: each pool is slightly different. this is built to work with 3crv, but also has "exchange_underlying"
interface ICurvePool {

    function A() external view returns (uint256 out);

    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;

    function admin_fee() external view returns (uint256 out);

    function balances(uint256 arg0) external view returns (uint256 out);

    // this is int128 in vyper
    function coins(uint256 arg0) external view returns (address out);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;

    function fee() external view returns (uint256 out);

    function future_A() external view returns (uint256 out);

    function future_fee() external view returns (uint256 out);

    function future_admin_fee() external view returns (uint256 out);

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function get_virtual_price() external view returns (uint256 out);

    function remove_liquidity(uint256 token_amount, uint256[3] memory min_amounts) external returns (uint256[3] memory);

    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount
    ) external returns (uint256);

}
