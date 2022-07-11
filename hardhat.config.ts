import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'
import 'hardhat-deploy'
import 'hardhat-watcher'
import 'hardhat-gas-reporter'
import 'solidity-coverage'
import '@openzeppelin/hardhat-upgrades'
import { task } from "hardhat/config";
require("dotenv").config();

export default {
  solidity: {
    compilers: [
      {
        version: "0.8.5",
        settings: {
          optimizer: {
            enabled: true,
            runs: 5,
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 600000,
  },

  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },
    localhost: {
      url: "http://localhost:8545",
    },
    mainnet: {
      url: process.env.MAINNET_RPC,
      accounts: process.env.DEVNET_PRIVKEY !== undefined ? [process.env.DEVNET_PRIVKEY] : [],
    },
    rinkeby: {
      url: process.env.RINKEBY_RPC,
      accounts: process.env.DEVNET_PRIVKEY !== undefined ? [process.env.DEVNET_PRIVKEY] : [],
    },
    arbitrumOne: {
      url: process.env.ARBITRUM_ONE_RPC,
      accounts: process.env.DEVNET_PRIVKEY !== undefined ? [process.env.DEVNET_PRIVKEY] : [],
    },
    arbitrumTestnet: {
      url: process.env.ARBITRUM_TESTNET_RPC,
      accounts: process.env.DEVNET_PRIVKEY !== undefined ? [process.env.DEVNET_PRIVKEY] : [],
    },
    emeraldTestnet: {
      url: process.env.EMERALD_TESTNET_RPC,
      accounts: process.env.DEVNET_PRIVKEY !== undefined ? [process.env.DEVNET_PRIVKEY] : [],
    },
    optimismTestnet: {
      url: process.env.OPTIMISM_TESTNET_RPC,
      accounts: process.env.DEVNET_PRIVKEY !== undefined ? [process.env.DEVNET_PRIVKEY] : [],
    }
  },
  watcher: {
    compilation: {
      tasks: ["compile"],
    },
    test: {
      tasks: ["test"],
      files: ["./test/*"],
    },
  }
}

const config = require("./config.json")
const { addLiquidity } = require('./scripts/commands/addLiquidity')
const { swapToken } = require('./scripts/commands/swapToken')
const { swapToExactToken } = require('./scripts/commands/swapToExactToken')
const { buyWithToken } = require('./scripts/commands/buyWithToken')
const { createOrderBook } = require('./scripts/commands/createOrderBook')

task("add-liquidity", "Add liquidity")
    .addOptionalParam('t1', 'token a address')
    .addParam('a1', 'token a amount')
    .addOptionalParam('t2', 'token b address')
    .addParam('a2', 'token b amount')
    .setAction(async (taskArgs, hre) => {
      await addLiquidity(hre.ethers, config, taskArgs.t1, taskArgs.a1, taskArgs.t2, taskArgs.a2)
    })

task("swap-token", "Swap token to token or eth")
    .addOptionalParam('t1', 'token a address')
    .addParam('a1', 'token a amount')
    .addOptionalParam('t2', 'token b address')
    .addOptionalParam('min', 'min output amount of token b')
    .setAction(async (taskArgs, hre) => {
      await swapToken(hre.ethers, config, taskArgs.t1, taskArgs.a1, taskArgs.t2, taskArgs.min)
    })

task("swap-to-exact-token", "Swap token or eth to exact amount token")
    .addOptionalParam('t1', 'token a address')
    .addOptionalParam('max', 'max input amount of token a')
    .addOptionalParam('t2', 'token b address')
    .addParam('a2', 'token b amount')
    .setAction(async (taskArgs, hre) => {
      await swapToExactToken(hre.ethers, config, taskArgs.t1, taskArgs.max, taskArgs.t2, taskArgs.a2)
    })

task("create-order-book", "Create order book")
    .addOptionalParam('base', 'token base address')
    .addOptionalParam('quote', 'token quote address')
    .setAction(async (taskArgs, hre) => {
      await createOrderBook(hre.ethers, config, taskArgs.base, taskArgs.quote)
    })

task("buy-with-token", "Buy token or eth with token at price")
    .addOptionalParam('base', 'token base address')
    .addParam('amount', 'buy amount')
    .addOptionalParam('quote', 'token quote address')
    .addParam('price', 'buy price')
    .setAction(async (taskArgs, hre) => {
      await buyWithToken(hre.ethers, config, taskArgs.base, taskArgs.quote, taskArgs.amount, taskArgs.price)
    })