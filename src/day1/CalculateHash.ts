import crypto from 'crypto';

function calculateHash(prefix: string, difficulty: number): void {
    let nonce = 0;
    const target = '0'.repeat(difficulty);
    const startTime = Date.now();

    while (true) {
        const content = `${prefix}${nonce}`;
        const hash = crypto.createHash('sha256').update(content).digest('hex');
        if (hash.startsWith(target)) {
            const elapsedTime = (Date.now() - startTime)
            console.log(`${difficulty} Leading Zeros:`);
            console.log(`Time: ${elapsedTime}s`);
            console.log(`Content: ${content}`);
            console.log(`Hash: ${hash}`);
            console.log();
            break;
        }
        nonce++;
    }
}

function main() {
    const nickname = 'zhaoyu';

    // Find hash with 4 leading zeros
    calculateHash(nickname, 4);

    // Find hash with 5 leading zeros
    calculateHash(nickname, 5);
}

main();
