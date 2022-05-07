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
    let pairRouter: Contract
    let pairUtils: Contract
    let tokenBase: Contract
    let tokenQuote: Contract
    let orderNFT: Contract
    beforeEach(async () => {
        const fixture = await loadFixture(orderBookFixture)
        pairFactory = fixture.pairFactory
        token0 = fixture.token0
        token1 = fixture.token1
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
        await tokenQuote.approve(orderBookRouter.address, expandTo6Decimals(100000))
        await tokenBase.approve(orderBookRouter.address, expandTo18Decimals(100000))
        let deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.buyWithToken(expandTo6Decimals(1), bigNumberify("2000000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)
        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.buyWithToken(expandTo6Decimals(1), bigNumberify("1900000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)
        let result = await orderBookRouter.getOrderBook(tokenBase.address, tokenQuote.address, bigNumberify(2))
        printOrderBook(result)

        deadline = Math.floor(Date.now() / 1000) + 200;
        await orderBookRouter.sellToken(expandTo18Decimals(1), bigNumberify("2000000"), tokenBase.address, tokenQuote.address, wallet.address, deadline)

        result = await orderBookRouter.getOrderBook(tokenBase.address, tokenQuote.address, bigNumberify(2))
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

        result = await orderNFT.getUserOrders(wallet.address);
        console.log(result)
    })
})
