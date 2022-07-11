const { Contract, BigNumber } = require('ethers')
const { formatUnits, parseUnits } = require("ethers/lib/utils")

let pairRouterJson = require('../../artifacts/contracts/periphery/pair/PairRouter.sol/PairRouter.json')
let orderBookFactoryJson = require('../../artifacts/contracts/core/orderbook/OrderBookFactory.sol/OrderBookFactory.json')
let orderBookJson = require('../../artifacts/contracts/core/orderbook/OrderBook.sol/OrderBook.json')
let erc20_abi = require('../../artifacts/contracts/test/ERC20.sol/ERC20.json').abi

const swapToken = async (ethers, config, tokenA, amountA, tokenB, amountBMin) => {
    try {
        const [wallet] = await ethers.getSigners()
        const chainId = await wallet.getChainId()
        const address = wallet.address
        const provider = wallet.provider

        config = config[chainId]
        console.log(address)
        //console.log(config)

        tokenA = tokenA?tokenA:config.baseAddress
        if (tokenA.toUpperCase() == "ETH"){
            console.log("ETH can not as a input token")
            return
        }
        tokenB = tokenB?tokenB:config.quoteAddress
        tokenB = "ETH" != tokenB.toUpperCase()?tokenB:config.wETH

        let orderBookFactory = new Contract(config.orderBookFactory, orderBookFactoryJson.abi, provider)

        let actions = [];
        let contractTokenA = new Contract(tokenA, erc20_abi, provider);
        let contractTokenAWithSigner = contractTokenA.connect(wallet);
        let aDecimal
        let aName
        let aDecimalAction = contractTokenA.decimals().then((data) => {
            aDecimal = data;
            console.log("TokenADecimal:" + aDecimal);
        });

        let aNameAction = contractTokenA.symbol().then((data) => {
            aName = data;
            console.log("TokenAName:" + aName);
        });

        actions.push(aNameAction, aDecimalAction)

        let contractTokenB = new Contract(tokenB, erc20_abi, provider);
        let contractTokenBWithSigner = contractTokenB.connect(wallet);
        let bDecimal
        let bName
        let bDecimalAction = contractTokenB.decimals().then((data) => {
            bDecimal = data;
            console.log("TokenBDecimal:" + bDecimal);
        });

        let bNameAction = contractTokenB.symbol().then((data) => {
            bName = data;
            console.log("TokenBName:" + bName);
        });

        actions.push(bNameAction, bDecimalAction)

        let orderBookAddress
        let getOrderBookAction = orderBookFactory.getOrderBook(tokenA, tokenB).then((data) => {
            orderBookAddress = data;
            console.log("OrderBookAddress:" + orderBookAddress);
        });

        actions.push(getOrderBookAction)

        await Promise.all(actions).then(() => {
            console.log("All init step are done!");
        });

        let priceDecimal
        let priceName
        if (orderBookAddress != "0x0000000000000000000000000000000000000000"){
            let orderBook = new Contract(orderBookAddress, orderBookJson.abi, provider)
            priceDecimal = await orderBook.priceDecimal()
            priceName = (await orderBook.quoteToken()).toLowerCase() == tokenA.toLowerCase() ? aName : bName
            let price = await orderBook.getPrice()
            console.log("price before swap:", formatUnits(price, priceDecimal), priceName)
        }

        let estimateGasPrice  = await provider.getGasPrice()
        let tokenAAmountRaw = parseUnits(amountA, aDecimal)
        let tokenBAmountMinRaw = amountBMin ? parseUnits(amountBMin, bDecimal) : BigNumber.from("0")
        let data = await contractTokenAWithSigner.allowance(address, config.hybridXRouter)
        if (data.lt(tokenAAmountRaw)) {
            console.log("wait to approve user's", aName, "spend by", config.hybridXRouter)
            if (!data.eq(BigNumber.from("0"))) {
                let tx = await contractTokenAWithSigner.approve(config.hybridXRouter, BigNumber.from("0"))
                await tx.wait()
            }
            let tx = await contractTokenAWithSigner.approve(config.hybridXRouter, BigNumber.from("0xffffffffffffffffffffffffffffffff"))
            await tx.wait()
        }

        let uniswapRouter = new Contract(config.hybridXRouter, pairRouterJson.abi, provider);
        let uniswapRouterWithSigner = uniswapRouter.connect(wallet)

        let deadline = Math.floor(Date.now() / 1000) + 200;
        let estimateGasLimit = await uniswapRouterWithSigner.estimateGas.swapExactTokensForTokens(tokenAAmountRaw, tokenBAmountMinRaw, [tokenA, tokenB], address, deadline)
        let overrides = {
            gasLimit: estimateGasLimit,
            gasPrice:  estimateGasPrice
        }
        let tx = await uniswapRouterWithSigner.swapExactTokensForTokens(tokenAAmountRaw, tokenBAmountMinRaw, [tokenA, tokenB], address, deadline, overrides)
        console.log("swap", amountA, aName, "to", bName+", tx =", tx.hash + ", gasLimit=", estimateGasLimit.toString())
        await tx.wait()

        if (orderBookAddress != "0x0000000000000000000000000000000000000000"){
            let orderBook = new Contract(orderBookAddress, orderBookJson.abi, provider)
            let price = await orderBook.getPrice()
            console.log("price after swap:", formatUnits(price, priceDecimal), priceName)
        }
    }catch (e) {
        console.log(e);
    }
};

module.exports = {
    swapToken
}
