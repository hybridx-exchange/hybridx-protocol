const { Contract, BigNumber } = require('ethers')
const { formatUnits, parseUnits } = require("ethers/lib/utils")

let orderBookRouterJson = require('../../artifacts/contracts/periphery/orderbook/OrderBookRouter.sol/OrderBookRouter.json')
let orderBookFactoryJson = require('../../artifacts/contracts/core/orderbook/OrderBookFactory.sol/OrderBookFactory.json')
let orderBookJson = require('../../artifacts/contracts/core/orderbook/OrderBook.sol/OrderBook.json')
let erc20_abi = require('../../artifacts/contracts/test/ERC20.sol/ERC20.json').abi

const buyWithToken = async (ethers, config, baseToken, quoteToken, amount, price) => {
    try {
        const [wallet] = await ethers.getSigners()
        const chainId = await wallet.getChainId()
        const address = wallet.address
        const provider = wallet.provider

        config = config[chainId]
        console.log(address)

        baseToken = baseToken?baseToken:config.baseAddress
        baseToken = "ETH" != baseToken.toUpperCase()?baseToken:config.wETH
        quoteToken = quoteToken?quoteToken:config.quoteAddress

        let orderBookFactory = new Contract(config.orderBookFactory, orderBookFactoryJson.abi, provider)

        let actions = [];
        let contractBase = new Contract(baseToken, erc20_abi, provider);
        let contractBaseWithSigner = contractBase.connect(wallet);
        let baseDecimal
        let baseName
        let baseDecimalAction = contractBase.decimals().then((data) => {
            baseDecimal = data;
            console.log("baseDecimal:" + baseDecimal);
        });

        let baseNameAction = contractBase.symbol().then((data) => {
            baseName = data;
            console.log("baseName:" + baseName);
        });

        actions.push(baseNameAction, baseDecimalAction)

        let contractQuote = new Contract(quoteToken, erc20_abi, provider);
        let contractQuoteWithSigner = contractQuote.connect(wallet);
        let quoteDecimal
        let quoteName
        let quoteDecimalAction = contractQuote.decimals().then((data) => {
            quoteDecimal = data;
            console.log("quoteDecimal:" + quoteDecimal);
        });

        let quoteNameAction = contractQuote.symbol().then((data) => {
            quoteName = data;
            console.log("quoteName:" + quoteName);
        });

        actions.push(quoteNameAction, quoteDecimalAction)

        let orderBookAddress
        let getOrderBookAction = orderBookFactory.getOrderBook(baseToken, quoteToken).then((data) => {
            orderBookAddress = data;
            console.log("OrderBookAddress:" + orderBookAddress);
        });

        actions.push(getOrderBookAction)

        await Promise.all(actions).then(() => {
            console.log("All init step are done!");
        });

        let quoteBalance = await contractQuote.balanceOf(address)
        console.log('quote balance', formatUnits(quoteBalance, quoteDecimal))

        if (orderBookAddress != "0x0000000000000000000000000000000000000000"){
            let orderBook = new Contract(orderBookAddress, orderBookJson.abi, provider)
            let price = await orderBook.getPrice()
            let base = await orderBook.baseToken()
            if (base !== baseToken) {
                console.log("base token and quote token mismatch")
                return
            }
            console.log("price before buy with token: 1", baseName, "=", formatUnits(price, quoteDecimal), quoteName)
        } else {
            console.log("order book not exist")
        }

        let estimateGasPrice  = await provider.getGasPrice()
        let amountRaw = parseUnits(amount, quoteDecimal)
        let data = await contractQuoteWithSigner.allowance(address, config.hybridXRouter)
        if (data.lt(amountRaw)) {
            console.log("wait to approve user's", quoteName, "spend by", config.hybridXRouter)
            if (!data.eq(BigNumber.from("0"))) {
                let tx = await contractQuoteWithSigner.approve(config.hybridXRouter, BigNumber.from("0"))
                await tx.wait()
            }
            let tx = await contractQuoteWithSigner.approve(config.hybridXRouter, BigNumber.from("0xffffffffffffffffffffffffffffffff"))
            await tx.wait()
        }

        let hybridXRouter = new Contract(config.hybridXRouter, orderBookRouterJson.abi, provider);
        let hybridXRouterWithSigner = hybridXRouter.connect(wallet)

        let deadline = Math.floor(Date.now() / 1000) + 200;
        let priceRaw = parseUnits(price, quoteDecimal)
        let estimateGasLimit = await hybridXRouterWithSigner.estimateGas.buyWithToken(amountRaw, priceRaw, baseToken, quoteToken, address, deadline)
        let overrides = {
            gasLimit: estimateGasLimit,
            gasPrice: estimateGasPrice
        }

        let tx = await hybridXRouterWithSigner.buyWithToken(amountRaw, priceRaw, baseToken, quoteToken, address, deadline, overrides)
        console.log("buy", baseName, "with", amount, quoteName, "at price", price, quoteName+", tx =", tx.hash+", gasLimit=", estimateGasLimit.toString())
        await tx.wait()

        if (orderBookAddress != "0x0000000000000000000000000000000000000000"){
            let orderBook = new Contract(orderBookAddress, orderBookJson.abi, provider)
            let price = await orderBook.getPrice()
            console.log("price after buy with token: 1", baseName, "=", formatUnits(price, quoteDecimal), quoteName)
        }
    }catch (e) {
        console.log(e);
    }
};

module.exports = {
    buyWithToken
}
