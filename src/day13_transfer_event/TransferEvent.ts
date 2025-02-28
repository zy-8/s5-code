import {erc20Abi, formatUnits, decodeFunctionData, parseAbiItem} from 'viem'
import {publicClient, publicWsClient} from '../day10_viem/client'

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7"

/**
 * 查询最近一百个区块 USDC Transfer事件
 */
async function get100BlockTransferEvent() {
    const blockNumber = await publicClient.getBlockNumber();
    const logs = await publicClient.getContractEvents({
        address: USDC_ADDRESS,
        abi: erc20Abi,
        eventName: 'Transfer',
        fromBlock: blockNumber - 99n,
        toBlock: blockNumber
    })

    console.log('最近100个区块的 Transfer 事件:')
    logs.forEach((log) => {
        console.log({
            from: log.args.from,
            to: log.args.to,
            value: formatUnits(log.args.value!, 6),
            transactionHash: log.transactionHash
        })
    })
}

/**
 * 实时查询USDC的Transfer事件
 */
async function getTransferEvent() {
    publicClient.watchContractEvent({
        address: USDC_ADDRESS,
        abi: erc20Abi,
        eventName: 'Transfer',
        onLogs: (logs) => {
            console.log('USDC Transfer 事件:', logs)
        }
    })
}

/**
 * 实时监控pending的交易
 */
async function getPendingTransfer() {
    const unwatch = await publicWsClient.watchPendingTransactions({
        poll: true,
        pollingInterval: 1_000,
        onTransactions: hashes => console.log('Pending transactions:', hashes),
    })
    // 保持程序运行60秒
    await new Promise((resolve) => setTimeout(resolve, 60_000))
    unwatch()
}


/**
 * 监听USDT 的Transfer Pending 交易
 */
async function getContractPendingTransferEvent(tokenAddress: `0x${string}`) {
    // 监听 pending 交易
    const unwatch = publicWsClient.watchPendingTransactions({
        onTransactions: async(hashes) => {
            // console.log('Pending transactions:', hashes)
            for (const hash of hashes) {
                try {
                    const transaction = await publicClient.getTransaction({ hash })

                    // 检查是否是tokenAddress合约交易
                    if (transaction.to?.toLowerCase() === tokenAddress.toLowerCase()) {
                        try {
                            const { args, functionName } = decodeFunctionData({
                                abi: erc20Abi,
                                data: transaction.input
                            })

                            // 检查是否是transfer或transferFrom函数
                            if (functionName === 'transfer' || functionName === 'transferFrom') {
                                console.log('发现 USDT Transfer Pending 交易:')
                                console.log({
                                    blockNumber: transaction.blockNumber,
                                    hash: transaction.hash,
                                    from: transaction.from,
                                    to: args[0],  // 接收地址
                                    value: formatUnits(args[1] as bigint, 6),  // USDC 6位小数
                                    gasPrice: formatUnits(transaction.gasPrice || 0n, 9), // Gas价格（Gwei）
                                    functionName
                                })
                            }
                        } catch (error) {
                            // 解析交易数据失败，可能不是transfer交易
                            continue
                        }
                    }
                } catch (error) {
                    console.error(`处理交易 ${hash} 时出错:`, error)
                }
            }
        },
        onError: (error) => {
            console.error('监听错误:', error)
        }
    })

    console.log('开始监听 USDC Transfer Pending 交易...')
    // 保持程序运行30分钟
    await new Promise((resolve) => setTimeout(resolve, 30 * 1000 * 60))
    console.log('停止监听')
    unwatch()
}

async function main() {
    // await get100BlockTransferEvent();
    await getContractPendingTransferEvent(USDT_ADDRESS)
}

main()