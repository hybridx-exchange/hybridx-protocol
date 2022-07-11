const { Contract, BigNumber } = require('ethers')
const { formatUnits, parseUnits } = require("ethers/lib/utils")
let pairRouterJson = require('../../artifacts/contracts/periphery/pair/PairRouter.sol/PairRouter.json')
let orderBookFactoryJson = require('../../artifacts/contracts/core/orderbook/OrderBookFactory.sol/OrderBookFactory.json')
let orderBookJson = require('../../artifacts/contracts/core/orderbook/OrderBook.sol/OrderBook.json')
let erc20_abi = require('../../artifacts/contracts/test/ERC20.sol/ERC20.json').abi

const addLiquidity = async (ethers, config, tokenA, amountA, tokenB, amountB) => {
    try {
        const [wallet] = await ethers.getSigners()
        const chainId = await wallet.getChainId()
        const address = wallet.address
        const provider = wallet.provider

        config = config[chainId]
        console.log(address)
        //console.log(config)

        tokenA = tokenA?tokenA:config.baseAddress
        tokenA = "ETH" != tokenA.toUpperCase()?tokenA:config.wETH
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

        if (orderBookAddress != "0x0000000000000000000000000000000000000000"){
            let orderBook = new Contract(orderBookAddress, orderBookJson.abi, provider)
            let priceDecimal = await orderBook.priceDecimal()
            let price = await orderBook.getPrice()
            console.log("price before add liquidity:", formatUnits(price, priceDecimal))
        }

        let tokenAAmountRaw = amountA?parseUnits(amountA, aDecimal):BigNumber.from("1")
        let tokenBAmountRaw = amountB?parseUnits(amountB, bDecimal):BigNumber.from("1")
        let tokenAAmountMinRaw = BigNumber.from("0")
        let tokenBAmountMinRaw = BigNumber.from("0")
        if (tokenA != config.wethAddress){
            let data1 = await contractTokenAWithSigner.allowance(address, config.hybridXRouter)
            if (data1.lt(tokenAAmountRaw)) {
                console.log("wait to approve user's", aName, "spend by", config.hybridXRouter)
                if (!data1.eq(BigNumber.from("0"))) {
                    let tx = await contractTokenAWithSigner.approve(config.hybridXRouter, BigNumber.from("0"))
                    await tx.wait()
                }
                let tx = await contractTokenAWithSigner.approve(config.hybridXRouter, BigNumber.from("0xffffffffffffffffffffffffffffffff"))
                await tx.wait()
            }
        }

        if (tokenB != config.wethAddress){
            let data2 = await contractTokenBWithSigner.allowance(address, config.hybridXRouter)
            if (data2.lt(tokenBAmountRaw)) {
                console.log("wait to approve user's", bName, "spend by", config.hybridXRouter)
                if (!data2.eq(BigNumber.from("0"))){
                    let tx = await contractTokenBWithSigner.approve(config.hybridXRouter, BigNumber.from("0"))
                    await tx.wait()
                }
                let tx = await contractTokenBWithSigner.approve(config.hybridXRouter, BigNumber.from("0xffffffffffffffffffffffffffffffff"))
                await tx.wait()
            }
        }

        let pairRouter = new Contract(config.hybridXRouter, pairRouterJson.abi, provider);
        let pairRouterWithSigner = pairRouter.connect(wallet)

        let deadline = Math.floor(Date.now() / 1000) + 200;
        if (tokenA == config.wETH) {
            let overrides = {
                value: tokenAAmountRaw
            }
            deadline = Math.floor(Date.now() / 1000) + 200;
            let tx = await pairRouterWithSigner.addLiquidityETH(tokenB, tokenBAmountRaw, tokenBAmountMinRaw, tokenAAmountMinRaw, address, deadline, overrides)
            await tx.wait()
            console.log("add", amountA, aName, "and", amountB, bName, "to liquidity pool, tx =", tx.hash)
        }
        else if (tokenB == config.wETH) {
            let overrides = {
                value: tokenBAmountRaw
            }
            deadline = Math.floor(Date.now() / 1000) + 200;
            let tx = await pairRouterWithSigner.addLiquidityETH(tokenA, tokenAAmountRaw, tokenAAmountMinRaw, tokenBAmountMinRaw, address, deadline, overrides)
            await tx.wait()
            console.log("add", amountA, aName, "and", amountB, bName, "to liquidity pool, tx =", tx.hash)
        }
        else {
            deadline = Math.floor(Date.now() / 1000) + 200;
            let tx = await pairRouterWithSigner.addLiquidity(tokenA, tokenB, tokenAAmountRaw, tokenBAmountRaw, tokenAAmountMinRaw, tokenBAmountMinRaw, address, deadline)
            console.log("add", amountA, aName, "and", amountB, bName, "to liquidity pool, tx =", tx.hash)
            await tx.wait()
        }

        if (orderBookAddress != "0x0000000000000000000000000000000000000000"){
            let orderBook = Contract(orderBookAddress, orderBookJson.abi, provider)
            let priceDecimal = await orderBook.priceDecimal()
            let price = await orderBook.getPrice()
            console.log("price after add liquidity:", formatUnits(price, priceDecimal))
        }
    } catch (e) {
        console.log(e);
    }
};

module.exports = {
    addLiquidity
}
