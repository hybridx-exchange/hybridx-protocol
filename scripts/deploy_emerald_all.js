const { Contract } = require('ethers')
const { Interface, formatUnits, keccak256, toUtf8Bytes, arrayify } = require("ethers/lib/utils")
const { ethers } = require("hardhat")
const { saveConfig, loadConfig } = require("./config")
const OrderNFTJson = require("../artifacts/contracts/core/orderbook/OrderNFT.sol/OrderNFT.json");
const OrderBookQueryJson = require("../artifacts/contracts/core/orderbook/OrderBookQuery.sol/OrderBookQuery.json");
const OrderBookJson = require("../artifacts/contracts/core/orderbook/OrderBook.sol/OrderBook.json");
const IOrderBookFactoryJson = require("../artifacts/contracts/core/orderbook/interfaces/IOrderBookFactory.sol/IOrderBookFactory.json");
const IOrderBookRouterJson = require("../artifacts/contracts/periphery/orderbook/interfaces/IOrderBookRouter.sol/IOrderBookRouter.json");
const IPairRouterJson = require("../artifacts/contracts/periphery/pair/interfaces/IPairRouter.sol/IPairRouter.json");
const IPairUtilsJson = require("../artifacts/contracts/periphery/pair/interfaces/IPairUtils.sol/IPairUtils.json");
const IConfigJson = require("../artifacts/contracts/config/interfaces/IConfig.sol/IConfig.json");
const HybridXRouterABI = require("../artifacts/contracts/periphery/HybridXRouter.sol/HybridXRouter.json").abi;

const wETHAddress="0xb9ab821f7323dB4357Bf71eA66670C01761c3d73"
const baseAddress = "0x7736CCe944377ECa85feb4AF0C19c0AF2f6Ec10e"
const quoteAddress = "0x1a56ED83b3773f662Fe2C471F6a3952432a4CFCd"

const overrides = {
    gasLimit: 12999999
}

const configPath = "./config.json"

const getFunctionSelector = (fragment) => {
    let inputs = fragment.inputs.map(i => {
        return i.type
    })

    let fragmentStr = fragment.name + '('
    inputs.forEach((e, i) => {
        if (i == 0) {
            fragmentStr += e;
        }
        else {
            fragmentStr += ',' + e;
        }
    })

    fragmentStr += ')'
    //console.log(fragmentStr)
    return keccak256(toUtf8Bytes(fragmentStr)).substring(0, 10)
}

const deploy = async () => {
    const [wallet] = await ethers.getSigners()
    let balance = await wallet.getBalance()
    console.log(wallet.address, formatUnits(balance, 18))

    let chainId = await wallet.getChainId()
    let provider = wallet.provider
    let configContent = loadConfig(configPath)
    configContent[chainId] = configContent[chainId] ? configContent[chainId] : {}
    configContent[chainId].wETH = wETHAddress
    configContent[chainId].baseAddress = baseAddress
    configContent[chainId].quoteAddress = quoteAddress
    configContent[chainId].step = configContent[chainId].step ?? 0

    if (configContent[chainId].step < 1) {
        const Config = await ethers.getContractFactory("Config");
        const config = await Config.deploy(wETHAddress, overrides);
        await config.deployed()
        configContent[chainId].config = config.address
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('config address:', config.address)
    }

    if (configContent[chainId].step < 2) {
        const PairFactory = await ethers.getContractFactory('PairFactory')
        const pairFactory = await PairFactory.deploy(configContent[chainId].config, overrides)
        await pairFactory.deployed()
        configContent[chainId].pairFactory = pairFactory.address

        const pairInitHash = await pairFactory.getCodeHash()
        configContent[chainId].pairInitHash = pairInitHash

        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('pair factory address:', pairFactory.address)
    }

    if (configContent[chainId].step < 3) {
        let config = new Contract(configContent[chainId].config, JSON.stringify(IConfigJson.abi), provider).connect(wallet)
        let tx = await config.setPairFactory(configContent[chainId].pairFactory, overrides)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('set pair factory address:')
    }

    if (configContent[chainId].step < 4) {
        const OrderBookFactory = await ethers.getContractFactory('OrderBookFactory')
        const orderBookFactory = await OrderBookFactory.deploy(configContent[chainId].config, overrides)
        await orderBookFactory.deployed()
        configContent[chainId].orderBookFactory = orderBookFactory.address
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('order book factory address:', orderBookFactory.address)
    }

    if (configContent[chainId].step < 5) {
        let config = new Contract(configContent[chainId].config, JSON.stringify(IConfigJson.abi), provider).connect(wallet)
        let tx = await config.setOrderBookFactory(configContent[chainId].orderBookFactory, overrides)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('set order book factory address:')
    }

    if (configContent[chainId].step < 6) {
        const OrderBookQuery = await ethers.getContractFactory('OrderBookQuery')
        const orderBookQuery = await OrderBookQuery.deploy(overrides)
        await orderBookQuery.deployed()
        configContent[chainId].orderBookQuery = orderBookQuery.address
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('order book query address:', orderBookQuery.address)
    }

    if (configContent[chainId].step < 7) {
        let config = new Contract(configContent[chainId].config, JSON.stringify(IConfigJson.abi), provider).connect(wallet)
        let tx = await config.setOrderBookQuery(configContent[chainId].orderBookQuery, overrides)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('set order book query address:')
    }

    let orderBookByteCode = OrderBookJson.bytecode.substring(2, OrderBookJson.bytecode.length)
    let orderBookPartLen = (orderBookByteCode.length / 2) - (orderBookByteCode.length / 2 % 2)

    if (configContent[chainId].step < 8) {
        let config = new Contract(configContent[chainId].config, JSON.stringify(IConfigJson.abi), provider).connect(wallet)
        let tx = await config.appendOrderBookByteCode(arrayify('0x' + orderBookByteCode.substring(0, orderBookPartLen)), 0, overrides)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log("appendOrderBookByteCode 0")
    }

    if (configContent[chainId].step < 9) {
        let config = new Contract(configContent[chainId].config, JSON.stringify(IConfigJson.abi), provider).connect(wallet)
        let tx = await config.appendOrderBookByteCode(arrayify('0x' + orderBookByteCode.substring(orderBookPartLen, orderBookByteCode.length)), 1, overrides)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log("appendOrderBookByteCode 1")
    }

    let orderNFTByteCode = OrderNFTJson.bytecode.substring(2, OrderNFTJson.bytecode.length)
    let orderNFTPartLen = (orderNFTByteCode.length / 2) - (orderNFTByteCode.length / 2 % 2)

    if (configContent[chainId].step < 10) {
        let config = new Contract(configContent[chainId].config, JSON.stringify(IConfigJson.abi), provider).connect(wallet)
        let tx = await config.appendOrderNFTByteCode(arrayify('0x' + orderNFTByteCode.substring(0, orderNFTPartLen)), 0, overrides)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log("appendOrderNFTByteCode 0")
    }

    if (configContent[chainId].step < 11) {
        let config = new Contract(configContent[chainId].config, JSON.stringify(IConfigJson.abi), provider).connect(wallet)
        let tx = await config.appendOrderNFTByteCode(arrayify('0x' + orderNFTByteCode.substring(orderNFTPartLen, orderNFTByteCode.length)), 1, overrides)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log("appendOrderNFTByteCode 1")
    }

    if (configContent[chainId].step < 12) {
        const PairRouter = await ethers.getContractFactory('PairRouter')
        let pairRouter = await PairRouter.deploy(configContent[chainId].config, overrides)
        await pairRouter.deployed()
        configContent[chainId].pairRouter = pairRouter.address
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('pair router address:', pairRouter.address)
    }

    if (configContent[chainId].step < 13) {
        const PairUtils = await ethers.getContractFactory('PairUtils')
        let pairUtils = await PairUtils.deploy(configContent[chainId].config, overrides)
        await pairUtils.deployed()
        configContent[chainId].pairUtils = pairUtils.address
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('pair utils address:', pairUtils.address)
    }

    if (configContent[chainId].step < 14) {
        const OrderBookRouter = await ethers.getContractFactory('OrderBookRouter')
        let orderBookRouter = await OrderBookRouter.deploy(configContent[chainId].config, overrides)
        await orderBookRouter.deployed()
        configContent[chainId].orderBookRouter = orderBookRouter.address
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('order book router address:', orderBookRouter.address)
    }

    if (configContent[chainId].step < 15) {
        const HybridXRouter = await ethers.getContractFactory('HybridXRouter')
        const hybridXRouter = await HybridXRouter.deploy(configContent[chainId].config, overrides)
        await hybridXRouter.deployed()
        configContent[chainId].hybridXRouter = hybridXRouter.address
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
        console.log('hybrid router address', hybridXRouter.address)
    }

    const orderBookRouterInterface = new Interface(IOrderBookRouterJson.abi)
    let functionIds = []
    orderBookRouterInterface.fragments.forEach((fragment) => {
        if (fragment.type === 'function') {
            functionIds.push(getFunctionSelector(fragment))
        }
    })

    //console.log(orderBookRouter.address, functionIds)
    if (configContent[chainId].step < 16) {
        let hybridXRouter = new Contract(configContent[chainId].hybridXRouter, JSON.stringify(HybridXRouterABI), provider).connect(wallet)
        let tx = await hybridXRouter.bindFunctions(configContent[chainId].orderBookRouter, functionIds)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
    }

    const pairRouterInterface = new Interface(IPairRouterJson.abi)
    functionIds = []
    pairRouterInterface.fragments.forEach((fragment) => {
        if (fragment.type === 'function') {
            functionIds.push(getFunctionSelector(fragment))
        }
    })

    //console.log(pairRouter.address, functionIds)
    if (configContent[chainId].step < 17) {
        let hybridXRouter = new Contract(configContent[chainId].hybridXRouter, JSON.stringify(HybridXRouterABI), provider).connect(wallet)
        let tx = await hybridXRouter.bindFunctions(configContent[chainId].pairRouter, functionIds)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
    }

    const pairUtilsInterface = new Interface(IPairUtilsJson.abi)
    functionIds = []
    pairUtilsInterface.fragments.forEach((fragment) => {
        if (fragment.type === 'function') {
            functionIds.push(getFunctionSelector(fragment))
        }
    })

    //console.log(pairUtils.address, functionIds)
    if (configContent[chainId].step < 18) {
        let hybridXRouter = new Contract(configContent[chainId].hybridXRouter, JSON.stringify(HybridXRouterABI), provider).connect(wallet)
        let tx = await hybridXRouter.bindFunctions(configContent[chainId].pairUtils, functionIds)
        await tx.wait()
        configContent[chainId].step = configContent[chainId].step + 1
        saveConfig(configContent, configPath)
    }

    if (configContent[chainId].step === 18) {
        let orderBookFactory = new Contract(configContent[chainId].orderBookFactory, JSON.stringify(IOrderBookFactoryJson.abi), provider)
        const orderNFTInitHash = await orderBookFactory.getOrderNFTCodeHash()
        configContent[chainId].orderNFTInitHash = orderNFTInitHash
        const orderBookInitHash = await orderBookFactory.getOrderBookCodeHash()
        configContent[chainId].orderBookInitHash = orderBookInitHash

        configContent[chainId].step = 0
        saveConfig(configContent, configPath)
    }

    console.log('export const CONFIG_ADDRESS = \'' + configContent[chainId].config + '\'')
    console.log('export const FACTORY_ADDRESS = \'' + configContent[chainId].pairFactory + '\'')
    console.log('export const INIT_CODE_HASH = \'' + configContent[chainId].pairInitHash + '\'')
    console.log('export const ORDER_BOOK_FACTORY_ADDRESS = \'' + configContent[chainId].orderBookFactory + '\'')
    console.log('export const ORDER_BOOK_INIT_CODE_HASH = \'' + configContent[chainId].orderBookInitHash + '\'')
    console.log('export const ORDER_NFT_INIT_CODE_HASH = \'' + configContent[chainId].orderNFTInitHash + '\'')
    console.log('export const HYBRID_ROUTER_ADDRESS = \'' + configContent[chainId].hybridXRouter + '\'')
}

deploy()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

