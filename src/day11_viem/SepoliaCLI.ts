import {createPublicClient, createWalletClient, erc20Abi, formatUnits, http, parseEther, parseUnits} from 'viem'
import {sepolia} from 'viem/chains'
import {generatePrivateKey, privateKeyToAccount} from 'viem/accounts'


// 创建客户端
const publicClient = createPublicClient({
    chain: sepolia,
    transport: http()
})

const walletClient = createWalletClient({
    chain: sepolia,
    transport: http()
})

/**
 * 生成钱包
 */
async function generateWallet() {
    //生成钱包
    const privateKey = generatePrivateKey();
    //私钥导入
    const account = privateKeyToAccount(privateKey);
    console.log('New wallet generated:')
    console.log('Private Key:', privateKey)
    console.log('Address:', account.address)
    return {privateKey, account}
}


/**
 * 查询eth余额
 */
async function getWalletBalance(address: `0x${string}`) {
    try {
        //eth余额
        const balance = await publicClient.getBalance({address})
        const ethBalance = parseEther(balance.toString())
        console.log('ETH balance:',ethBalance)
        return balance
    } catch (error) {
        console.error('Error checking balance:', error)
        throw error
    }
}

/**
 * 查询erc20余额
 */
async function getTokenBalance(tokenAddress: `0x${string}`, address: `0x${string}`) {

    try {
        const [tokenBalance, decimals] = await Promise.all([
            publicClient.readContract({
                address: tokenAddress,
                abi: erc20Abi,
                functionName: 'balanceOf',
                args: [address]
            }),
            getTokenDecimals(tokenAddress)
        ])
        const formattedBalance = formatUnits(tokenBalance, decimals)
        console.log('Token Balance:', formattedBalance)
        return {tokenBalance, decimals, formattedBalance}
    } catch (error) {
        console.error('Error checking token balance:', error)
        throw error
    }
}

// 获取代币精度
async function getTokenDecimals(tokenAddress: `0x${string}`): Promise<number> {
    try {
        const decimals = await publicClient.readContract({
            address: tokenAddress,
            abi: erc20Abi,
            functionName: 'decimals'
        })
        return decimals
    } catch (error) {
        console.error('Error getting token decimals:', error)
        throw error
    }
}

/**
 * 构建 ERC20 转账
 */
async function transferERC20(privateKey: `0x${string}`, tokenAddress: `0x${string}`, toAddress: `0x${string}`, amount: number) {
    try {
        const account = privateKeyToAccount(privateKey);
        const {tokenBalance,decimals,} = await getTokenBalance(tokenAddress, account.address);
        // 转换金额到正确的精度
        const rawAmount = parseUnits(amount.toString(), decimals)
        if (tokenBalance >= rawAmount) {
            //构建交易数据
            const {request} = await publicClient.simulateContract({
                account,
                address: tokenAddress,
                abi: erc20Abi,
                functionName: 'transfer',
                args: [toAddress, rawAmount]
            })
            //签名并发送交易
            const hash = await walletClient.writeContract(request)
            //等待交易确认
            const receipt = await publicClient.waitForTransactionReceipt({hash})
            console.log('Transaction confirmed in hash:', hash)
            return receipt
        } else {
            console.log('Token Insufficient balance:', account.address)
        }
    } catch (error) {
        console.error('Error sending transaction:', error)
        throw error
    }
}

async function main() {

    const masterPrivateKey = '0x'
    const masterAccount = privateKeyToAccount(masterPrivateKey);

    //生成钱包
    console.log('Generating new wallet...')
    const {privateKey, account} = await generateWallet()
    //查询eth余额
    console.log('\nChecking ETH balance...')
    await getWalletBalance(masterAccount.address);

    const tokenAddress = '0xC5E67BfA4dB90b4a3fcd803a224dF3d9099c3E00'
    //转移100个Token到生成钱包账户
    const amount = 100;
    await transferERC20(masterPrivateKey, tokenAddress, account.address, amount)

    //查询 ERC20 余额
    await getTokenBalance(tokenAddress, account.address)
}

main();

