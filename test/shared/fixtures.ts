import { Contract, Wallet, utils } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './utilities'

import ERC20 from '../../build/ERC20.json'
import Config from '../../build/Config.json'
import PairFactory from '../../build/PairFactory.json'
import Pair from '../../build/Pair.json'
import OrderBookFactory from '../../build/OrderBookFactory.json'
import OrderBook from '../../build/OrderBook.json'
import OrderNFT from '../../build/OrderNFT.json'
import WETH from '../../build/WETH9.json'

interface FactoryFixture {
  tokenA: Contract
  tokenB: Contract
  config: Contract
  pairFactory: Contract
  orderBookFactory: Contract
}

const overrides = {
  gasLimit: 15999999
}

export async function factoryFixture(_: Web3Provider, [wallet]: Wallet[]): Promise<FactoryFixture> {
  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(30000)], overrides)
  const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(30000)], overrides)
  const weth = await deployContract(wallet, WETH, [], overrides)
  const config = await deployContract(wallet, Config, [weth.address], overrides)
  const pairFactory = await deployContract(wallet, PairFactory, [config.address], overrides)
  await config.setPairFactory(pairFactory.address, overrides);
  const orderBookFactory = await deployContract(wallet, OrderBookFactory, [config.address], overrides)
  await config.setOrderBookFactory(orderBookFactory.address, overrides)
  await config.setOrderBookByteCode(utils.arrayify('0x' + OrderBook.evm.bytecode.object), overrides)
  await config.setOrderNFTByteCode(utils.arrayify('0x' + OrderNFT.evm.bytecode.object), overrides)
  return { tokenA, tokenB, config, pairFactory, orderBookFactory }
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
  const { tokenA, tokenB, config, pairFactory, orderBookFactory } = await factoryFixture(provider, [wallet])

  await pairFactory.createPair(tokenA.address, tokenB.address, overrides)
  const pairAddress = await pairFactory.getPair(tokenA.address, tokenB.address)
  const pair = new Contract(pairAddress, JSON.stringify(Pair.abi), provider).connect(wallet)

  const token0Address = await pair.token0()
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  //await orderBookFactory.createOrderNFT(tokenA.address, tokenB.address, overrides)
  await orderBookFactory.createOrderBook(tokenA.address, tokenB.address, overrides)

  const orderBookAddress = await orderBookFactory.getOrderBook(tokenA.address, tokenB.address)
  const orderBook = new Contract(orderBookAddress, JSON.stringify(OrderBook.abi), provider).connect(wallet)
  const baseToken = new Contract(await orderBook.baseToken(), JSON.stringify(ERC20.abi), provider).connect(wallet)
  const quoteToken = new Contract(await orderBook.quoteToken(), JSON.stringify(ERC20.abi), provider).connect(wallet)

  const token0Amount = expandTo18Decimals(5)
  const token1Amount = expandTo18Decimals(10)
  await token0.transfer(pair.address, token0Amount)
  await token1.transfer(pair.address, token1Amount)
  await pair.mint(wallet.address, overrides)

  return { config, pairFactory, orderBookFactory, token0, token1, pair, baseToken, quoteToken, orderBook, tokenA, tokenB }
}
