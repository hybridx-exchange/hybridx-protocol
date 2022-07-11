const { Contract } = require('ethers')

let orderBookFactoryJson = require('../../artifacts/contracts/core/orderbook/OrderBookFactory.sol/OrderBookFactory.json')
let erc20_abi = require('../../artifacts/contracts/test/ERC20.sol/ERC20.json').abi

const createOrderBook = async (ethers, config, baseToken, quoteToken) => {
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
        quoteToken = "ETH" != quoteToken.toUpperCase()?quoteToken:config.wETH

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

        if (orderBookAddress != "0x0000000000000000000000000000000000000000"){
            console.log("order book already exist")
            return
        }

        let estimateGasPrice  = await provider.getGasPrice()
        let orderBookFactoryWithSigner = orderBookFactory.connect(wallet)
        console.log(estimateGasPrice.toString())
        let estimateGasLimit = await orderBookFactoryWithSigner.estimateGas.createOrderBook(baseToken, quoteToken)
        let overrides = {
            gasLimit: estimateGasLimit,
            gasPrice: estimateGasPrice
        }

        let tx = await orderBookFactoryWithSigner.createOrderBook(baseToken, quoteToken, overrides)
        console.log("create order book with base token", baseName, "and quote token", quoteName+", tx =", tx.hash)
        await tx.wait()
    }catch (e) {
        console.log(e);
    }
};

module.exports = {
    createOrderBook
}
