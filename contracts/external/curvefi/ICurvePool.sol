// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.6;

interface ICurvePool {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external;
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) external;   

    function get_virtual_price() external returns (uint256 out);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy,
        uint256 deadline
    ) external;

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy,
        uint256 deadline
    ) external;

    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount,
        bool use_underlying
    ) external returns (uint256);

    function remove_liquidity(uint256 token_amount, uint256[2] memory min_amount, bool _use_underlying) external returns (uint256[2] memory);
    function remove_liquidity(uint256 token_amount, uint256[3] memory min_amount, bool _use_underlying) external returns (uint256[3] memory);
    function remove_liquidity(uint256 token_amount, uint256[4] memory min_amount, bool _use_underlying) external returns (uint256[4] memory);

    function coins(int128 arg0) external returns (address out);

    function underlying_coins(int128 arg0) external returns (address out);

    function balances(int128 arg0) external returns (uint256 out);

    function A() external returns (int128 out);

    function fee() external returns (int128 out);

    function admin_fee() external returns (int128 out);

    function future_A() external returns (int128 out);

    function future_fee() external returns (int128 out);

    function future_admin_fee() external returns (int128 out);
}
