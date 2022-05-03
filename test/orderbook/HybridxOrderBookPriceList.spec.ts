import chai from 'chai'
import {Contract} from 'ethers'
import {solidity, MockProvider, createFixtureLoader} from 'ethereum-waffle'
import {bigNumberify, formatUnits} from 'ethers/utils'

import {expandTo18Decimals, expandTo6Decimals, printOrderBook} from '../shared/utilities'
import {orderBookFixture} from '../shared/fixtures'

chai.use(solidity)

const overrides = {
    gasLimit: 19999999
}

describe('HybridxOrderBook', () => {
    const provider = new MockProvider({
        hardfork: 'istanbul',
        mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
        gasLimit: 19999999
    })
    const [wallet, other] = provider.getWallets()
    const loadFixture = createFixtureLoader(provider, [wallet])

    let pairFactory: Contract
    let token0: Contract
    let token1: Contract
    let pair: Contract
    let orderBook: Contract
    let orderBookFactory: Contract
    let orderBookRouter: Contract
    let tokenBase: Contract
    let tokenQuote: Contract
    beforeEach(async () => {
        const fixture = await loadFixture(orderBookFixture)
        pairFactory = fixture.pairFactory
        token0 = fixture.token0
        token1 = fixture.token1
        pair = fixture.pair
        orderBook = fixture.orderBook
        orderBookFactory = fixture.orderBookFactory
        orderBookRouter = fixture.orderBookRouter
        tokenBase = fixture.tokenA
        tokenQuote = fixture.tokenB
    })

    it('priceList test', async () => {
        console.log("price", (await orderBook.getPrice()).toString())
        let limitAmount = expandTo18Decimals(1)
        /*let limitPrices = [
            bigNumberify("2100000000000000000"),
            bigNumberify("2200000000000000000"),
            bigNumberify("2300000000000000000"),
            bigNumberify("2400000000000000000"),
            bigNumberify("2500000000000000000"),
            bigNumberify("2600000000000000000"),
            bigNumberify("2700000000000000000"),
            bigNumberify("2800000000000000000")]
        for (let i = 0; i < limitPrices.length; i++) {
            //await tokenBase.transfer(orderBook.address, limitAmount)
            //await orderBook.createSellLimitOrder(wallet.address, limitPrices[i], wallet.address, overrides)
        }

        let result = await orderBook.rangeBook(bigNumberify(2), expandTo18Decimals(4))
        console.log(result)

        limitPrices = [
            bigNumberify("2000000000000000000"),
            bigNumberify("1900000000000000000")
        ]
        for (let i = 0; i < limitPrices.length; i++) {
            await tokenQuote.transfer(orderBook.address, limitAmount)
            await orderBook.createBuyLimitOrder(wallet.address, limitPrices[i], wallet.address, overrides)
        }

        result = await orderBook.rangeBook(bigNumberify(1), expandTo18Decimals(1))
        console.log(result)

        await tokenBase.transfer(orderBook.address, limitAmount.mul(2))
        await orderBook.createSellLimitOrder(wallet.address, bigNumberify("1900000000000000000"), wallet.address, overrides)

        console.log("price", (await orderBook.getPrice()).toString())

        result = await orderBook.rangeBook(bigNumberify(1), expandTo18Decimals(0))
        console.log(result)

        result = await orderBook.rangeBook(bigNumberify(2), expandTo18Decimals(4))
        console.log(result)*/

        await tokenQuote.approve(orderBookRouter.address, expandTo6Decimals(100000))
        await tokenBase.approve(orderBookRouter.address, expandTo18Decimals(100000))
        let deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.buyWithToken(limitAmount, bigNumberify("2000000000000000000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)
        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.buyWithToken(limitAmount, bigNumberify("1900000000000000000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)
        let result = await orderBookRouter.getOrderBook(tokenBase.address, tokenQuote.address, bigNumberify(2))
        printOrderBook(result)

        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.sellToken(expandTo18Decimals(3), bigNumberify("2000000000000000000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)

        result = await orderBookRouter.getOrderBook(tokenBase.address, tokenQuote.address, bigNumberify(2))
        printOrderBook(result)
    })
})
