import { Contract, Wallet, utils } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'

import {expandTo18Decimals, expandTo6Decimals} from './utilities'

import ERC20 from '../../build/ERC20.json'
import ERC20Decimal6 from '../../build/ERC20Decimal6.json'
import Config from '../../build/Config.json'
import PairFactory from '../../build/PairFactory.json'
import PairRouter from '../../build/PairRouter.json'
import Pair from '../../build/Pair.json'
import OrderBookFactory from '../../build/OrderBookFactory.json'
import OrderBookRouter from '../../build/OrderBookRouter.json'
import OrderBook from '../../build/OrderBook.json'
import OrderNFT from '../../build/OrderNFT.json'
import WETH from '../../build/WETH9.json'

interface FactoryFixture {
  tokenA: Contract
  tokenB: Contract
  config: Contract
  pairFactory: Contract
  pairRouter: Contract
  orderBookFactory: Contract
  orderBookRouter: Contract
}

const overrides = {
  gasLimit: 15999999
}

export async function factoryFixture(_: Web3Provider, [wallet]: Wallet[]): Promise<FactoryFixture> {
  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(30000)], overrides)
  const tokenB = await deployContract(wallet, ERC20Decimal6, [expandTo6Decimals(30000)], overrides)
  const weth = await deployContract(wallet, WETH, [], overrides)
  const config = await deployContract(wallet, Config, [weth.address], overrides)
  const pairFactory = await deployContract(wallet, PairFactory, [config.address], overrides)
  await config.setPairFactory(pairFactory.address, overrides);
  console.log("config pair factory:", await config.getPairFactory())
  const orderBookFactory = await deployContract(wallet, OrderBookFactory, [config.address], overrides)
  await config.setOrderBookFactory(orderBookFactory.address, overrides)
  await config.setOrderBookByteCode(utils.arrayify('0x' + OrderBook.evm.bytecode.object), overrides)
  await config.setOrderNFTByteCode(utils.arrayify('0x' + OrderNFT.evm.bytecode.object), overrides)
  const pairRouter = await deployContract(wallet, PairRouter, [config.address], overrides)
  const orderBookRouter = await deployContract(wallet, OrderBookRouter, [config.address], overrides)
  return { tokenA, tokenB, config, pairFactory, pairRouter, orderBookFactory, orderBookRouter }
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
}

export async function orderBookFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<OrderBookFixture> {
  const { tokenA, tokenB, config, pairFactory, pairRouter, orderBookFactory, orderBookRouter } = await factoryFixture(provider, [wallet])

  const tokenAAmount = expandTo18Decimals(1)
  const tokenBAmount = expandTo18Decimals(2)
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

  return { config, pairFactory, pairRouter, orderBookFactory, orderBookRouter, token0, token1, pair, baseToken, quoteToken, orderBook, tokenA, tokenB }
}
