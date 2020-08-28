liquidgastoken doesnt use decimals. remove the /100.0

i like the features coming from OpenZeppelin, but they take more gas than if I wrote them myself (especially with the GSN checking code)

do we want to keep using kollateral? 0.6% fee
- using dydx directly is free and has plenty of liquidity for us, but less tokens
- what about uniswap flash loans? 0.3% fee 
  - from kollateral: "We have been looking into it, one concern is that by leveraging uniswap, we may end up adversely influencing the states/prices of the uniswap markets (inside of the transaction) which the flash loaner may want to actually use as part of their defi operation"
  - me: "have you seen 1split? they use flags to enable/disable different backends. maybe something like that could work"
- aave? 0.09% fee

- [Flash arbitrage - zero price risk arbitrage between Uniswap v1 and v2](https://github.com/Uniswap/uniswap-v2-periphery/pull/17/files)
