import { Contract, Wallet, utils } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals, expandTo6Decimals, getFunctionSelector } from './utilities'

import ERC20 from '../../build/ERC20.json'
import ERC20Decimal6 from '../../build/ERC20Decimal6.json'
import Config from '../../build/Config.json'
import PairFactory from '../../build/PairFactory.json'
import PairRouter from '../../build/PairRouter.json'
import PairUtils from '../../build/PairUtils.json'
import Pair from '../../build/Pair.json'
import OrderBookFactory from '../../build/OrderBookFactory.json'
import OrderBookRouter from '../../build/OrderBookRouter.json'
import OrderBook from '../../build/OrderBook.json'
import OrderNFT from '../../build/OrderNFT.json'
import WETH from '../../build/WETH9.json'
import HybridXRouter from '../../build/HybridXRouter.json'
import IOrderBookRouter from '../../build/IOrderBookRouter.json'
import IPairRouter from '../../build/IPairRouter.json'
import IPairUtils from '../../build/IPairUtils.json'
import {FunctionFragment} from "ethers/utils";
import { expect } from "chai";

interface FactoryFixture {
  tokenA: Contract
  tokenB: Contract
  weth: Contract
  config: Contract
  pairFactory: Contract
  pairRouter: Contract
  pairUtils: Contract
  orderBookFactory: Contract
  orderBookRouter: Contract
}

const overrides = {
  gasLimit: 15999999
}

export async function factoryFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<FactoryFixture> {
  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(30000)], overrides)
  const tokenB = await deployContract(wallet, ERC20Decimal6, [expandTo6Decimals(30000)], overrides)
  const weth = await deployContract(wallet, WETH, [], overrides)
  const config = await deployContract(wallet, Config, [weth.address], overrides)
  const pairFactory = await deployContract(wallet, PairFactory, [config.address], overrides)
  await config.setPairFactory(pairFactory.address, overrides);
  const orderBookFactory = await deployContract(wallet, OrderBookFactory, [config.address], overrides)
  await config.setOrderBookFactory(orderBookFactory.address, overrides)
  await config.setOrderBookByteCode(utils.arrayify('0x' + OrderBook.evm.bytecode.object), overrides)
  await config.setOrderNFTByteCode(utils.arrayify('0x' + OrderNFT.evm.bytecode.object), overrides)
  let pairRouter = await deployContract(wallet, PairRouter, [config.address], overrides)
  let pairUtils = await deployContract(wallet, PairUtils, [config.address], overrides)
  let orderBookRouter = await deployContract(wallet, OrderBookRouter, [config.address], overrides)
  const hybridXRouter = await deployContract(wallet, HybridXRouter, [config.address], overrides);

  console.log('hybridXRouterAddress', hybridXRouter.address)

  const orderBookRouterInterface = new utils.Interface(IOrderBookRouter.abi)
  let functionIds: string[] = []
  orderBookRouterInterface.abi.forEach((fragment) => {
    if (fragment.type === 'function') {
      functionIds.push(getFunctionSelector(fragment as FunctionFragment))
    }
  })

  //console.log(orderBookRouter.address, functionIds)
  await hybridXRouter.bindFunctions(orderBookRouter.address, functionIds)

  const pairRouterInterface = new utils.Interface(IPairRouter.abi)
  functionIds = []
  pairRouterInterface.abi.forEach((fragment) => {
    if (fragment.type === 'function') {
      functionIds.push(getFunctionSelector(fragment as FunctionFragment))
    }
  })

  //console.log(pairRouter.address, functionIds)
  await hybridXRouter.bindFunctions(pairRouter.address, functionIds)

  const pairUtilsInterface = new utils.Interface(IPairUtils.abi)
  functionIds = []
  pairUtilsInterface.abi.forEach((fragment) => {
    if (fragment.type === 'function') {
      functionIds.push(getFunctionSelector(fragment as FunctionFragment))
    }
  })

  //console.log(pairUtils.address, functionIds)
  await hybridXRouter.bindFunctions(pairUtils.address, functionIds)

  //pairRouter = new Contract(hybridXRouter.address, JSON.stringify(IPairRouter.abi), provider).connect(wallet)
  //pairUtils = new Contract(hybridXRouter.address, JSON.stringify(IPairUtils.abi), provider).connect(wallet)
  //orderBookRouter = new Contract(hybridXRouter.address, JSON.stringify(IOrderBookRouter.abi), provider).connect(wallet)

  return { tokenA, tokenB, weth, config, pairFactory, pairRouter, pairUtils, orderBookFactory, orderBookRouter }
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

export async function orderBookFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<OrderBookFixture> {
  const { tokenA, tokenB, weth, config, pairFactory, pairRouter, pairUtils, orderBookFactory, orderBookRouter } = await factoryFixture(provider, [wallet])

  const tokenAAmount = expandTo18Decimals(11)
  const tokenBAmount = 18186779
  const zero = expandTo18Decimals(0)
  await tokenA.approve(pairRouter.address, tokenAAmount)
  await tokenB.approve(pairRouter.address, tokenBAmount)
  let deadline = Math.floor(Date.now() / 1000) + 200;
  await pairRouter.addLiquidity(tokenA.address, tokenB.address, tokenAAmount, tokenBAmount, zero, zero, wallet.address, deadline, overrides)

  const pairAddress = await pairFactory.getPair(tokenA.address, tokenB.address)
  const pair = new Contract(pairAddress, JSON.stringify(Pair.abi), provider).connect(wallet)

  const token0Address = await pair.token0()
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  await orderBookFactory.createOrderBook(tokenA.address, tokenB.address, overrides)

  const orderBookAddress = await orderBookFactory.getOrderBook(tokenA.address, tokenB.address)
  const orderBook = new Contract(orderBookAddress, JSON.stringify(OrderBook.abi), provider).connect(wallet)
  const baseToken = new Contract(await orderBook.baseToken(), JSON.stringify(ERC20.abi), provider).connect(wallet)
  const quoteToken = new Contract(await orderBook.quoteToken(), JSON.stringify(ERC20.abi), provider).connect(wallet)
  const orderNFTAddress = await orderBook.orderNFT();
  const orderNFT = new Contract(orderNFTAddress, JSON.stringify(OrderNFT.abi), provider).connect(wallet)

  return { config, pairFactory, pairRouter, pairUtils, orderBookFactory, orderBookRouter, token0, token1, weth, pair, baseToken, quoteToken, orderBook, tokenA, tokenB, orderNFT }
}
