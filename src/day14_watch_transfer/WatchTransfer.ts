import { erc20Abi, formatUnits, decodeFunctionData, parseAbiItem } from 'viem'
import { publicClient, publicWsClient } from '../day10_viem/client'

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7"

async function watchLatestBlock() {
    const unwatch = publicClient.watchBlocks({
        onBlock: block => {
            //hash number
            console.log(`最新区块: ${block.number} ${block.hash} ${block.timestamp}`)
            console.log(`baseFeePerGas(此区块的基础费用): ${formatUnits(block.baseFeePerGas || 0n, 9)} gasLimit(此区块允许的最大 gas 数量): ${block.gasLimit} gasUsed(此区块实际使用的 gas 量): ${block.gasUsed}`)
        }
    })
    console.log('开始监听最新区块信息...')
    // 保持程序运行30分钟
    await new Promise((resolve) => setTimeout(resolve, 30 * 1000 * 60))
    console.log('停止监听')
    unwatch()
}
/**
 * 监听USDT 的Transfer 最新交易
 */
async function watchContractLatestTransferEvent(tokenAddress: `0x${string}`) {
    const unwatch = publicWsClient.watchEvent({
        address: tokenAddress,
        event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)'),
        onLogs: logs => {
            for (const log of logs) {
                console.log(`在 ${log.blockNumber} 区块 ${log.blockHash} 交易中从 ${log.args.from} 转账 ${formatUnits(log.args.value as bigint, 6)} USDT 到 ${log.args.to}`)
            }
        }
    })
    console.log('开始监听 USDT Transfer 交易...')
    // 保持程序运行30分钟
    await new Promise((resolve) => setTimeout(resolve, 30 * 1000 * 60))
    console.log('停止监听')
    unwatch()
}

async function main() {
    await Promise.all([
        watchLatestBlock(),
        watchContractLatestTransferEvent(USDT_ADDRESS)
    ])
}

main()