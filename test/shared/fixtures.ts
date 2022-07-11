import { Contract, Wallet, utils, BigNumber } from 'ethers'
import { expandTo18Decimals, expandTo6Decimals, getFunctionSelector } from './utilities'

import { ERC20 } from '../../typechain/ERC20'
import { ERC20Decimal6 } from '../../typechain/ERC20Decimal6'
import { Config } from '../../typechain/Config'
import { PairFactory } from '../../typechain/PairFactory'
import { PairRouter } from '../../typechain/PairRouter'
import { PairUtils } from '../../typechain/PairUtils'
import { Pair } from '../../typechain/Pair'
import { OrderBookFactory } from '../../typechain/OrderBookFactory'
import { OrderBookQuery } from '../../typechain/OrderBookQuery'
import { OrderBookRouter } from '../../typechain/OrderBookRouter'
import { OrderBook } from '../../typechain/OrderBook'
import { OrderNFT } from '../../typechain/OrderNFT'
import { WETH9 } from '../../typechain/WETH9'
import { HybridXRouter } from '../../typechain/HybridXRouter'
import { FunctionFragment } from "ethers/lib/utils"
// @ts-ignore
import { ethers } from "hardhat";

const OrderBookJson = require("../../artifacts/contracts/core/orderbook/OrderBook.sol/OrderBook.json")
const OrderBookQueryJson = require("../../artifacts/contracts/core/orderbook/OrderBookQuery.sol/OrderBookQuery.json")
const OrderNFTJson = require("../../artifacts/contracts/core/orderbook/OrderNFT.sol/OrderNFT.json")
const IOrderBookRouterJson = require("../../artifacts/contracts/periphery/orderbook/interfaces/IOrderBookRouter.sol/IOrderBookRouter.json")
const IPairRouterJson = require("../../artifacts/contracts/periphery/pair/interfaces/IPairRouter.sol/IPairRouter.json")
const IPairUtilsJson = require("../../artifacts/contracts/periphery/pair/interfaces/IPairUtils.sol/IPairUtils.json")
const IPairJson = require("../../artifacts/contracts/core/pair/interfaces/IPair.sol/IPair.json")
const IERC20Json = require("../../artifacts/contracts/test/ERC20.sol/ERC20.json")
const IOrderBookJson = require("../../artifacts/contracts/core/orderbook/interfaces/IOrderBook.sol/IOrderBook.json")
const IOrderNFTJson = require("../../artifacts/contracts/core/orderbook/interfaces/IOrderNFT.sol/IOrderNFT.json")

interface FactoryFixture {
  tokenA: Contract
  tokenB: Contract
  wETH: Contract
  config: Contract
  pairFactory: Contract
  pairRouter: Contract
  pairUtils: Contract
  orderBookFactory: Contract
  orderBookRouter: Contract
}

const overrides = {
  gasLimit: 19999999
}

export async function factoryFixture(wallet, provider): Promise<FactoryFixture> {
  let balance = await wallet.getBalance()
  console.log('balance', utils.formatEther(balance))
  const ERC20 = await ethers.getContractFactory('ERC20')
  const ERC20Decimal6 = await ethers.getContractFactory('ERC20Decimal6')
  const tokenA = (await ERC20.deploy(BigNumber.from(10).pow(25), overrides)) as ERC20
  const tokenB = (await ERC20Decimal6.deploy(BigNumber.from(10).pow(11), overrides)) as ERC20Decimal6

  const WETH = await ethers.getContractFactory('WETH9')
  const wETH = (await WETH.deploy(overrides)) as WETH9

  const Config = await ethers.getContractFactory('Config')
  const config = (await Config.deploy(wETH.address, overrides)) as Config

  const PairFactory = await ethers.getContractFactory('PairFactory')
  const pairFactory = (await PairFactory.deploy(config.address, overrides)) as PairFactory

  await config.setPairFactory(pairFactory.address, overrides);

  const OrderBookFactory = await ethers.getContractFactory('OrderBookFactory')
  const orderBookFactory = (await OrderBookFactory.deploy(config.address, overrides)) as OrderBookFactory
  await config.setOrderBookFactory(orderBookFactory.address, overrides)

  const OrderBookQuery = await ethers.getContractFactory('OrderBookQuery')
  const orderBookQuery = (await OrderBookQuery.deploy(overrides)) as OrderBookQuery
  await config.setOrderBookQuery(orderBookQuery.address, overrides)

  await config.setOrderNFTByteCode(utils.arrayify(OrderNFTJson.bytecode), overrides)
  await config.setOrderBookByteCode(utils.arrayify(OrderBookJson.bytecode), overrides)

  const PairRouter = await ethers.getContractFactory('PairRouter')
  let pairRouter = (await PairRouter.deploy(config.address, overrides)) as PairRouter

  const PairUtils = await ethers.getContractFactory('PairUtils')
  let pairUtils = (await PairUtils.deploy(config.address, overrides)) as PairUtils

  const OrderBookRouter = await ethers.getContractFactory('OrderBookRouter')
  let orderBookRouter = (await OrderBookRouter.deploy(config.address, overrides)) as OrderBookRouter

  const HybridXRouter = await ethers.getContractFactory('HybridXRouter')
  const hybridXRouter = (await HybridXRouter.deploy(config.address, overrides)) as HybridXRouter
  //console.log('hybridXRouterAddress', hybridXRouter.address)

  const orderBookRouterInterface = new utils.Interface(IOrderBookRouterJson.abi)
  let functionIds: string[] = []
  orderBookRouterInterface.fragments.forEach((fragment) => {
    if (fragment.type === 'function') {
      functionIds.push(getFunctionSelector(fragment as FunctionFragment))
    }
  })

  //console.log(orderBookRouter.address, functionIds)
  await hybridXRouter.bindFunctions(orderBookRouter.address, functionIds)

  const pairRouterInterface = new utils.Interface(IPairRouterJson.abi)
  functionIds = []
  pairRouterInterface.fragments.forEach((fragment) => {
    if (fragment.type === 'function') {
      functionIds.push(getFunctionSelector(fragment as FunctionFragment))
    }
  })

  //console.log(pairRouter.address, functionIds)
  await hybridXRouter.bindFunctions(pairRouter.address, functionIds)

  const pairUtilsInterface = new utils.Interface(IPairUtilsJson.abi)
  functionIds = []
  pairUtilsInterface.fragments.forEach((fragment) => {
    if (fragment.type === 'function') {
      functionIds.push(getFunctionSelector(fragment as FunctionFragment))
    }
  })

  //console.log(pairUtils.address, functionIds)
  await hybridXRouter.bindFunctions(pairUtils.address, functionIds)

  pairRouter = new Contract(hybridXRouter.address, JSON.stringify(IPairRouterJson.abi), provider).connect(wallet) as PairRouter
  pairUtils = new Contract(hybridXRouter.address, JSON.stringify(IPairUtilsJson.abi), provider).connect(wallet) as PairUtils
  orderBookRouter = new Contract(hybridXRouter.address, JSON.stringify(IOrderBookRouterJson.abi), provider).connect(wallet) as OrderBookRouter

  return { tokenA, tokenB, wETH, config, pairFactory, pairRouter, pairUtils, orderBookFactory, orderBookRouter }
}

interface PairFixture extends FactoryFixture {
  token0: Contract
  token1: Contract
  pair: Contract
}

interface OrderBookFixture extends PairFixture {
  baseToken: Contract
  quoteToken: Contract
  orderBook: Contract
  orderNFT: Contract
}

export async function orderBookFixture(): Promise<OrderBookFixture> {
  let [wallet, other] = await ethers.getSigners()
  let provider = await ethers.getDefaultProvider()
  const { tokenA, tokenB, wETH, config, pairFactory, pairRouter, pairUtils, orderBookFactory, orderBookRouter } =
      await factoryFixture(wallet, provider)

  const tokenAAmount = expandTo18Decimals(11)
  const tokenBAmount = 18186779
  const zero = expandTo18Decimals(0)
  await tokenA.approve(pairRouter.address, tokenAAmount)
  await tokenB.approve(pairRouter.address, tokenBAmount)
  let deadline = Math.floor(Date.now() / 1000) + 200;
  await pairRouter.addLiquidity(tokenA.address, tokenB.address, tokenAAmount, tokenBAmount, zero, zero, wallet.address, deadline, overrides)
  const overrides2 = {
    gasLimit: 9999999,
    value: expandTo18Decimals(10)
  }

  await tokenA.approve(pairRouter.address, expandTo18Decimals(10000))
  await tokenB.approve(pairRouter.address, expandTo6Decimals(10000))
  await pairRouter.addLiquidityETH(tokenA.address, expandTo18Decimals(10), zero, zero, wallet.address, deadline, overrides2)
  await pairRouter.addLiquidityETH(tokenB.address, expandTo6Decimals(10), zero, zero, wallet.address, deadline, overrides2)

  const pairAddress = await pairFactory.getPair(tokenA.address, tokenB.address)
  const pair = new Contract(pairAddress, JSON.stringify(IPairJson.abi), provider).connect(wallet)

  const token0Address = await pair.token0()
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  await orderBookFactory.createOrderBook(tokenA.address, tokenB.address, overrides)

  const orderBookAddress = await orderBookFactory.getOrderBook(tokenA.address, tokenB.address)
  const orderBook = new Contract(orderBookAddress, JSON.stringify(IOrderBookJson.abi), provider).connect(wallet)
  const baseToken = new Contract(await orderBook.baseToken(), JSON.stringify(IERC20Json.abi), provider).connect(wallet)
  const quoteToken = new Contract(await orderBook.quoteToken(), JSON.stringify(IERC20Json.abi), provider).connect(wallet)
  const orderNFTAddress = await orderBook.orderNFT();
  const orderNFT = new Contract(orderNFTAddress, JSON.stringify(IOrderNFTJson.abi), provider).connect(wallet)

  return { config, pairFactory, pairRouter, pairUtils, orderBookFactory, orderBookRouter, token0, token1, wETH, pair, baseToken, quoteToken, orderBook, tokenA, tokenB, orderNFT }
}
