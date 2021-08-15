/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
      hardhat: {
          hardfork: "london",
          // base fee of 0 allows use of 0 gas price when testing
          initialBaseFeePerGas: 0,
          // brownie expects calls and transactions to throw on revert
          throwOnTransactionFailures: true,
          throwOnCallFailures: true
     }
  }
}