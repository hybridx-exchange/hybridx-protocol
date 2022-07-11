// @ts-ignore
import { ethers } from 'hardhat'
import {BigNumber, Contract, Wallet} from 'ethers'
import {createFixtureLoader} from 'ethereum-waffle'
import {formatUnits} from 'ethers/lib/utils'

import {expandTo18Decimals, expandTo6Decimals, printOrderBook} from './shared/utilities'
import {orderBookFixture} from './shared/fixtures'

describe('HybridXOrderBook', () => {
    let wallet: Wallet, other: Wallet
    let loadFixture: ReturnType<typeof createFixtureLoader>

    let pairFactory: Contract
    let token0: Contract
    let token1: Contract
    let weth: Contract
    let pair: Contract
    let orderBook: Contract
    let orderBookFactory: Contract
    let orderBookRouter: Contract
    let pairRouter: Contract
    let pairUtils: Contract
    let tokenBase: Contract
    let tokenQuote: Contract
    let orderNFT: Contract

    before('create fixture loader', async () => {
        ;[wallet, other] = await (ethers as any).getSigners()
        loadFixture = createFixtureLoader([wallet, other])
    })

    beforeEach(async () => {
        const fixture = await loadFixture(orderBookFixture)
        pairFactory = fixture.pairFactory
        token0 = fixture.token0
        token1 = fixture.token1
        weth = fixture.wETH
        pair = fixture.pair
        orderBook = fixture.orderBook
        orderBookFactory = fixture.orderBookFactory
        orderBookRouter = fixture.orderBookRouter
        pairRouter = fixture.pairRouter
        pairUtils = fixture.pairUtils
        tokenBase = fixture.tokenA
        tokenQuote = fixture.tokenB
        orderNFT = fixture.orderNFT
    })

    it('priceList test', async () => {
        console.log("price", (await orderBook.getPrice()).toString())
        let result = await pairUtils.getAmountsOut(expandTo18Decimals(1), [tokenBase.address, tokenQuote.address])
        console.log(formatUnits(result.amounts[0], 18),
            formatUnits(result.amounts[1], 6),
            formatUnits(result.extra[0], 18),
            formatUnits(result.extra[1], 6),
            formatUnits(result.extra[2], 18),
            formatUnits(result.extra[3], 6),
            formatUnits(result.extra[4], 18),
            formatUnits(result.extra[5], 6))

        result = await pairUtils.getAmountsIn(result.amounts[1], [tokenBase.address, tokenQuote.address])
        console.log(formatUnits(result.amounts[0], 18),
            formatUnits(result.amounts[1], 6),
            formatUnits(result.extra[0], 18),
            formatUnits(result.extra[1], 6),
            formatUnits(result.extra[2], 18),
            formatUnits(result.extra[3], 6),
            formatUnits(result.extra[4], 18),
            formatUnits(result.extra[5], 6))

        await tokenQuote.approve(pairRouter.address, expandTo6Decimals(100000))
        await tokenBase.approve(pairRouter.address, expandTo18Decimals(100000))
        let deadline;
        let tx
        let ret
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapExactTokensForTokens(expandTo18Decimals(1), 0, [tokenBase.address, tokenQuote.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapExactTokensForTokens(expandTo18Decimals(2), 0, [tokenBase.address, tokenQuote.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapExactTokensForTokens(expandTo18Decimals(3), 0, [tokenBase.address, tokenQuote.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapTokensForExactTokens(expandTo6Decimals(2), expandTo18Decimals(1000), [tokenBase.address, tokenQuote.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapTokensForExactTokens(expandTo18Decimals(3), expandTo6Decimals(1000), [tokenQuote.address, tokenBase.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log('swapTokensForExactTokens', ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapTokensForExactTokens(expandTo18Decimals(4), expandTo6Decimals(1000), [tokenQuote.address, tokenBase.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log('swapTokensForExactTokens', ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapExactTokensForTokens(expandTo18Decimals(1), 0, [tokenBase.address, tokenQuote.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapExactTokensForTokens(expandTo18Decimals(2), 0, [tokenBase.address, tokenQuote.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapExactTokensForTokens(expandTo18Decimals(3), 0, [tokenBase.address, tokenQuote.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapTokensForExactTokens(expandTo6Decimals(2), expandTo18Decimals(1000), [tokenBase.address, tokenQuote.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapTokensForExactTokens(expandTo18Decimals(3), expandTo6Decimals(1000), [tokenQuote.address, tokenBase.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log('swapTokensForExactTokens', ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapTokensForExactTokens(expandTo18Decimals(4), expandTo6Decimals(1000), [tokenQuote.address, tokenBase.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log('swapTokensForExactTokens', ret.transactionHash)
        result = await pairUtils.getReserves(tokenBase.address, tokenQuote.address)
        console.log(formatUnits(result[0], 18), formatUnits(result[1], 6),
            formatUnits(await tokenBase.balanceOf(pair.address), 18), formatUnits(await tokenQuote.balanceOf(pair.address), 6))

        await tokenQuote.approve(orderBookRouter.address, expandTo6Decimals(100000))
        await tokenBase.approve(orderBookRouter.address, expandTo18Decimals(100000))
        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.buyWithToken(expandTo6Decimals(1), BigNumber.from("2000000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)
        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.buyWithToken(expandTo6Decimals(1), BigNumber.from("1900000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)
        result = await orderBookRouter.getOrderBook(tokenBase.address, tokenQuote.address, BigNumber.from(2))
        printOrderBook(result)

        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.sellToken(expandTo18Decimals(1), BigNumber.from("3000000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)

        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.buyWithToken(expandTo6Decimals(1), BigNumber.from("2000000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)

        result = await orderBookRouter.getOrderBook(tokenBase.address, tokenQuote.address, BigNumber.from(2))
        printOrderBook(result)

        result = await pairUtils.getAmountsOut(expandTo18Decimals(1), [tokenBase.address, tokenQuote.address])
        console.log(formatUnits(result.amounts[0], 18),
            formatUnits(result.amounts[1], 6),
            formatUnits(result.extra[0], 18),
            formatUnits(result.extra[1], 6),
            formatUnits(result.extra[2], 18),
            formatUnits(result.extra[3], 6),
            formatUnits(result.extra[4], 18),
            formatUnits(result.extra[5], 6))

        result = await pairUtils.getAmountsIn(expandTo6Decimals(1), [tokenBase.address, tokenQuote.address])
        console.log(formatUnits(result.amounts[0], 18),
            formatUnits(result.amounts[1], 6),
            formatUnits(result.extra[0], 18),
            formatUnits(result.extra[1], 6),
            formatUnits(result.extra[2], 18),
            formatUnits(result.extra[3], 6),
            formatUnits(result.extra[4], 18),
            formatUnits(result.extra[5], 6))

        result = await pairUtils.getAmountsIn(expandTo18Decimals(1), [tokenQuote.address, tokenBase.address])
        console.log('getAmountsIn')

        result = await orderNFT.getUserOrders(wallet.address);
        console.log('getUserOrders')

        const overrides = {
            value: expandTo18Decimals(1)
        }
        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapExactETHForTokens(0, [weth.address, tokenBase.address], wallet.address, deadline, overrides)
        ret = await tx.wait()
        console.log(ret.transactionHash)

        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapExactTokensForETH(expandTo18Decimals(1), 0, [tokenBase.address, weth.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)

        result = await pairUtils.getBestAmountsIn(expandTo6Decimals(1), [tokenBase.address, weth.address, tokenQuote.address], [3])
        console.log(result)

        result = await pairUtils.getBestAmountsIn(expandTo18Decimals(1), [tokenQuote.address, weth.address, tokenBase.address], [3])
        console.log(result)

        deadline = Math.floor(Date.now() / 1000) + 200;

        tx = await pairRouter.swapExactETHForTokens(0, [weth.address, tokenQuote.address], wallet.address, deadline, overrides)
        ret = await tx.wait()
        console.log(ret.transactionHash)

        deadline = Math.floor(Date.now() / 1000) + 200;
        tx = await pairRouter.swapExactTokensForETH(expandTo6Decimals(1), 0, [tokenQuote.address, weth.address], wallet.address, deadline)
        ret = await tx.wait()
        console.log(ret.transactionHash)

        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.sellEth(BigNumber.from("3000000"), tokenQuote.address, wallet.address, deadline, overrides)

        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.buyWithEth(BigNumber.from("3000000"), tokenBase.address, wallet.address, deadline, overrides)
    })
})
