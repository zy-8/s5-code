import { JsonRpcProvider, Wallet, parseEther, Contract } from 'ethers';
import { FlashbotsBundleProvider } from '@flashbots/ethers-provider-bundle';

// 配置信息
const CONFIG = {
    CONTRACT: '0xB3F33A179BD1Ab0917b0e994eAF7444B078677e6' as const,  // 目标合约地址
    PRIVATE_KEY: '' as `0x${string}`,
    RPC_URL: '',  // RPC URL
    FLASHBOTS_URL: 'https://relay-sepolia.flashbots.net',  // Flashbots RPC URL
    MINT_AMOUNT: 1n,  // mint 数量
    MINT_PRICE: '0.01',  // mint 价格 (ETH)
    GAS_LIMIT: 300000n,  // gas 限制
    OUTPUT_FILE: './bundle_results.json'  // 结果输出文件
};

// 合约 ABI
const ABI = [
    {
        name: "enablePresale",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [],
        outputs: []
    },
    {
        name: "presale",
        type: "function",
        stateMutability: "payable",
        inputs: [
            {
                name: "amount",
                type: "uint256"
            }
        ],
        outputs: []
    }
];

async function main() {
    console.log('=== Flashbots NFT Mint ===');
    console.log('目标合约:', CONFIG.CONTRACT);
    console.log('准备 Flashbots mint 交易');

    // 初始化 provider
    const provider = new JsonRpcProvider(CONFIG.RPC_URL);
    const wallet = new Wallet(CONFIG.PRIVATE_KEY, provider);

    // 创建 Flashbots 认证签名者（使用随机钱包）
    const authSigner = Wallet.createRandom();
    console.log('Flashbots 认证地址:', authSigner.address);

    // 创建 Flashbots provider
    const flashbotsProvider = await FlashbotsBundleProvider.create(
        provider,
        authSigner,
        CONFIG.FLASHBOTS_URL
    );

    try {
        // 获取当前 gas 价格
        const block = await provider.getBlock('latest');
        const baseFeePerGas = block.baseFeePerGas || parseEther('0.000001');
        const maxPriorityFeePerGas = parseEther('0.000001');
        const maxFeePerGas = baseFeePerGas * 2n + maxPriorityFeePerGas;

        // 创建合约实例
        const contract = new Contract(CONFIG.CONTRACT, ABI, wallet);

        // 准备交易数据
        const transaction = {
            to: CONFIG.CONTRACT,
            value: parseEther(CONFIG.MINT_PRICE),
            maxFeePerGas,
            maxPriorityFeePerGas,
            gasLimit: CONFIG.GAS_LIMIT,
            data: contract.interface.encodeFunctionData('presale', [CONFIG.MINT_AMOUNT]),
            chainId: (await provider.getNetwork()).chainId,
            nonce: await provider.getTransactionCount(wallet.address)
        };

        // 获取目标区块
        const blockNumber = await provider.getBlockNumber();
        const targetBlockNumber = blockNumber + 1;

        console.log(`准备发送 bundle 到区块 ${targetBlockNumber}`);

        // 签名并发送 bundle
        const signedTransactions = await flashbotsProvider.signBundle([
            {
                signer: wallet,
                transaction: transaction
            }
        ]);

        // 模拟 bundle
        const simulation = await flashbotsProvider.simulate(
            signedTransactions,
            targetBlockNumber
        );

        if ('error' in simulation) {
            console.log(`模拟失败: ${simulation.error.message}`);
            return;
        }

        console.log('模拟成功，发送 bundle...');

        // 发送 bundle
        const bundleSubmission = await flashbotsProvider.sendRawBundle(
            signedTransactions,
            targetBlockNumber
        );

        if ('error' in bundleSubmission) {
            throw new Error(`Bundle 提交失败: ${bundleSubmission.error.message}`);
        }

        console.log('Bundle 已提交，等待结果...');

        // 等待交易被打包
        const waitResponse = await bundleSubmission.wait();
        
        if (waitResponse === 0) {
            console.log('Bundle 已被包含在目标区块中!');
        } else if (waitResponse === 1) {
            console.log('Bundle 未被包含在目标区块中');
        } else if (waitResponse === 2) {
            console.log('Bundle 在目标区块过期');
        }

    } catch (error) {
        console.error('交易失败:', error);
    }

    // 优雅退出
    process.on('SIGINT', () => {
        console.log('\n停止监听...');
        process.exit(0);
    });
}

main().catch(error => console.error('程序执行错误:', error));