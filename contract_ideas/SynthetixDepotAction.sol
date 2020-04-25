/*
https://docs.synthetix.io/contracts/#depot
- The Depot is a vendor contract that allows users to exchange their ETH for sUSD or SNX, or their sUSD for SNX. It also allows users to deposit Synths to be sold in exchange for ETH.
- The depot has its own dedicated oracle, and all exchanges are performed at the current market prices, assuming sUSD is priced at one dollar.

I think that last part is especially interesting. It should create arbitrage opportunities.
*/
