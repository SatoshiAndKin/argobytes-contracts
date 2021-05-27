liquidgastoken doesnt use decimals. remove the /100.0

i like the features coming from OpenZeppelin, but they take more gas than if I wrote them myself (especially with the GSN checking code)

do we want to keep using kollateral? 0.6% fee
- using dydx directly is free and has plenty of liquidity for us, but less tokens
- what about uniswap flash loans? 0.3% fee 
  - from kollateral: "We have been looking into it, one concern is that by leveraging uniswap, we may end up adversely influencing the states/prices of the uniswap markets (inside of the transaction) which the flash loaner may want to actually use as part of their defi operation"
  - me: "have you seen 1split? they use flags to enable/disable different backends. maybe something like that could work"
- aave? 0.09% fee

- [Flash arbitrage - zero price risk arbitrage between Uniswap v1 and v2](https://github.com/Uniswap/uniswap-v2-periphery/pull/17/files)

======

deploy all contracts using LGT's helper
    - argobytesvault
    - argobytesproxyfactory
    - argobytesatomicactions

we can't and shouldnt fork dsauth and dsproxy. they are gpl and they also add an extra deploy cost to using
instead, write a function that uses gas tokens and maker's existing deployer. that should save us a large cost
some of our users will likely already have their own maker dsproxies, too

we could still have a proxy factory contract that buys and frees gas tokens. hopefully you can deploy with a low gas price though


test gas usage of different ways of doing proxying:
- proxy.execute(ArgobytesFactory.address, "", ExampleAction.initcode, exampleAction.burnGas(1000))
- proxy.execute(ExampleAction.address, exampleAction.burnGas(1000))

still not sure how we want to do gas token approvals vs buying 

we have two types of users

1. proxy owners
2. arbitrage bots

and there's two ways one might want to trade

- funds on an EOA. EOA uses proxy contract for combining actions
- funds on the proxy contract. EOA uses proxy contract for restricted trading

the same proxy should work for both, but the targets/sigs they call will likely be different

With #1, the contract doesn't need to hold any funds. and thanks to delegatecall, we don't need any approvals


=====

exponential delay on retry should wait from the time the request is sent, not from the time the error is received

brownie not being able to properly parse getAmounts makes investigating this difficult.

i don't think these are ready for mainnet yet. we still need to figure out how to handle tokenToToken selectors for cached orders. maybe encode that in exchange_data


=====

# web

when you click configure, the fallback node settings are empty. they should have their defaults

when you click "connect to wallet" and select wallet link, it gives a big error page instead of putting it into the page

=======

potential problem with websockets. we can't cancel an eth_call. if it were http, i think they would cancel when we close the client

we should add a semaphore on the web3 pending requests count

========

GUSD is way under the peg on DEXs. i think we should buy it and then sell it on gemini's exchange where the peg holds.
we can't do this atomically, but that should be fine.
my guess is that there is hardly any available for purchase on DEXs though.
guess was correct. uniswap liquidity: 0.3139 ETH + 62.75 GUSD


add the rest of the curve fi exchanges. that should mostly just be copy/paste


=======

Lasse Clausen, [May 12, 2020 at 11:42:02 AM]:
can I switch directly from one pool to the other?

or have to withdraw first, and then deposit

Michael, [May 12, 2020 at 11:43:46 AM]:
I think, withdraw/deposit. Direct switch isn't yet made.
Could be a zap which does it in a more or less optimal way, and another way (for small quantities) would be a "pool of pools"

- i think we should build our contracts so that they can do this
- then people can use "atomicTrade" to withdraw/deposit in one transaction

====

pooltogether pool where the sponsorship tokens give voting writes

charged particles. mint an NFT by depositing DAI. interest goes to contract owner. NFT can be burned to get money back.
- https://www.dfuse.io/en/hackathon-projects/charged-particles
- this would work better for game items. it allows for arbitrary minting. 
- what if price to mint isn't constant, but is instead a bonding curve such that more rare items are more expensive

need a rust tool that generates an ethereum mnemonic for us. the bot will use this. 

Ledger
0. satoshiandkin.eth
    - deploy contracts
    - admin contracts

Metamask Mnemonic
0. allowed arbitrager

- i think we will need a "max accounts" on the wallet so that we don't grow to big. do we have this already?

====

need to think more about the license. i think LGPL doesn't make sense with how smart contracts work. i want a license that keeps contracts open, but interfaces can be what the devs want.