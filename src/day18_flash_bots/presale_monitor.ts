import { JsonRpcProvider, WebSocketProvider, Wallet, parseEther, formatEther, Interface, Transaction } from 'ethers';
import { FlashbotsBundleProvider } from '@flashbots/ethers-provider-bundle';
import * as fs from 'fs';

interface Config {
    CONTRACT: string;
    PRIVATE_KEY: string;
    RPC_URL: string;
    WS_URL: string;
    RELAY_URL: string;
    MINT_AMOUNT: bigint;
    MINT_PRICE: string;
    GAS_LIMIT: bigint;
    BUNDLE_TIMEOUT: number;
}

const CONFIG: Config = {
    CONTRACT: '0xB3F33A179BD1Ab0917b0e994eAF7444B078677e6',
    PRIVATE_KEY: '',
    RPC_URL: '',
    WS_URL: '',
    RELAY_URL: 'https://relay-sepolia.flashbots.net',
    MINT_AMOUNT: 1n,
    MINT_PRICE: '0.01',
    GAS_LIMIT: 300000n,
    BUNDLE_TIMEOUT: 1000
};

class FlashbotsMonitor {
    private provider = new JsonRpcProvider(CONFIG.RPC_URL);
    private wsProvider = new WebSocketProvider(CONFIG.WS_URL);
    private wallet = new Wallet(CONFIG.PRIVATE_KEY, this.provider);
    private flashbots!: FlashbotsBundleProvider;
    private contractInterface = new Interface([
        "function enablePresale()",
        "function presale(uint256 amount) payable"
    ]);

    async start() {
        await this.initFlashbots();
        console.log('=== Flashbots Bundle Monitor ===');
        console.log('目标合约:', CONFIG.CONTRACT);
        console.log('\n开始监听 enablePresale 交易...');
        
        this.wsProvider.on('pending', this.handleTransaction.bind(this));
        process.on('SIGINT', () => {
            console.log('\n停止监听...');
            this.wsProvider.destroy();
            process.exit(0);
        });
    }

    private async initFlashbots() {
        const authSigner = Wallet.createRandom();
        console.log('Flashbots 认证地址:', authSigner.address);
        this.flashbots = await FlashbotsBundleProvider.create(
            this.provider,
            authSigner,
            CONFIG.RELAY_URL
        );
    }

    private async handleTransaction(hash: string) {
        try {
            const tx = await this.wsProvider.getTransaction(hash);

            if (!this.isEnablePresaleTx(tx)) return;

            console.log('\n发现 enablePresale 交易:', hash);
            const mintTx = await this.prepareMintTx(tx);
            await this.sendBundle(tx, mintTx, hash);
        } catch (error) {
            console.error('处理交易失败:', error);
        }
    }

    private isEnablePresaleTx(tx: any): boolean {
        if (!tx?.to || tx.to.toLowerCase() !== CONFIG.CONTRACT.toLowerCase()) return false;
        return tx.data?.startsWith(this.contractInterface.getFunction('enablePresale').selector);
    }

    private async prepareMintTx(tx: any) {
        const [chainId, nonce] = await Promise.all([
            this.provider.getNetwork().then(n => n.chainId),
            this.provider.getTransactionCount(this.wallet.address)
        ]);

        // 使用监听到的交易的 gas 价格，并提高 20%
        const maxFeePerGas = tx.maxFeePerGas 
            ? BigInt(tx.maxFeePerGas) * 120n / 100n 
            : parseEther('0.000002');//2 Gwei
        
        const maxPriorityFeePerGas = tx.maxPriorityFeePerGas
            ? BigInt(tx.maxPriorityFeePerGas) * 120n / 100n
            : parseEther('0.000002'); //2 Gwei

        console.log(`原始 Max Fee: ${formatEther(tx.maxFeePerGas || '0')} ETH`);
        console.log(`设置 Max Fee: ${formatEther(maxFeePerGas)} ETH`);
        console.log(`设置 Priority Fee: ${formatEther(maxPriorityFeePerGas)} ETH`);

        return {
            to: CONFIG.CONTRACT,
            data: this.contractInterface.encodeFunctionData('presale', [CONFIG.MINT_AMOUNT]),
            value: parseEther(CONFIG.MINT_PRICE),
            gasLimit: CONFIG.GAS_LIMIT,
            maxFeePerGas,
            maxPriorityFeePerGas,
            nonce,
            chainId,
            type: 2
        };
    }

    private async sendBundle(enableTx: any, mintTx: any, triggerTx: string) {
        const [signedMintTx, targetBlock, block] = await Promise.all([
            this.wallet.signTransaction(mintTx),
            this.provider.getBlockNumber().then(n => n + 1),
            this.provider.getBlock('latest')
        ]);

        const serializedEnableTx = Transaction.from({
            ...this.extractTxParams(enableTx),
            signature: {
                r: enableTx.signature.r!,
                s: enableTx.signature.s!,
                v: enableTx.signature.v!
            }
        }).serialized;

        console.log(`准备发送 bundle 到区块 ${targetBlock}`);
        const minTimestamp = block?.timestamp || Math.floor(Date.now() / 1000);


        await this.provider.getBlockNumber().then(n => console.log(n));

        const bundleReceipt = await this.flashbots.sendRawBundle(
            [serializedEnableTx, signedMintTx],
            targetBlock,
            { 
                minTimestamp, 
                maxTimestamp: minTimestamp + CONFIG.BUNDLE_TIMEOUT
            }
        );

        if ('error' in bundleReceipt) {
            throw new Error(`Bundle 提交失败: ${bundleReceipt.error.message}`);
        }

        const waitResponse = await bundleReceipt.wait();
        this.saveResult({ triggerTx, mintTx, targetBlock, waitResponse });
    }

    private extractTxParams(tx: any) {
        return {
            to: tx.to,
            nonce: tx.nonce,
            gasLimit: tx.gasLimit,
            data: tx.data,
            value: tx.value || 0,
            chainId: tx.chainId,
            maxFeePerGas: tx.maxFeePerGas,
            maxPriorityFeePerGas: tx.maxPriorityFeePerGas,
            type: tx.type
        };
    }

    private saveResult({ triggerTx, mintTx, targetBlock, waitResponse }: any) {
        const result = {
            timestamp: Date.now(),
            time: new Date().toLocaleString(),
            enablePresaleTx: triggerTx,
            mintTx: mintTx,
            targetBlock,
            success: waitResponse === 0,
            bundleStatus: this.getBundleStatus(waitResponse)
        };

        fs.writeFileSync('bundle_results.json', JSON.stringify(result, null, 2));
        console.log(`✅ Bundle ${result.success ? '成功' : '失败'}: ${result.bundleStatus}`);
        process.exit(0);
    }

    private getBundleStatus(waitResponse: number): string {
        const status = {
            0: '已被包含在目标区块中',
            1: '未被包含在目标区块中',
            2: '在目标区块过期'
        };
        return status[waitResponse as keyof typeof status] || '未知状态';
    }
}

new FlashbotsMonitor().start().catch(error => console.error('程序执行错误:', error)); 