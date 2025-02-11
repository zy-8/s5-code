import forge from "node-forge";
import crypto from "crypto";

// 生成 RSA 公私钥对
function generateKeyPair(): { publicKey: string; privateKey: string } {
    const keyPair = forge.pki.rsa.generateKeyPair({ bits: 2048, e: 0x10001 });
    const privateKey = forge.pki.privateKeyToPem(keyPair.privateKey);
    const publicKey = forge.pki.publicKeyToPem(keyPair.publicKey);
    return { publicKey, privateKey };
}

// 寻找符合 POW (4 个 0 开头的哈希值)
function findNonce(nickname: string): { nonce: number; hash: string } {
    let nonce = 0;
    let hash: string;

    do {
        const data = nickname + nonce;
        hash = crypto.createHash("sha256").update(data).digest("hex");
        nonce++;
    } while (!hash.startsWith("0000"));

    return { nonce: nonce - 1, hash };
}

// 用私钥对 "昵称 + nonce" 进行签名
function signData(privateKey: string, data: string): string {
    const privateKeyObj = forge.pki.privateKeyFromPem(privateKey);
    const md = forge.md.sha256.create();
    md.update(data, "utf8");
    const signature = privateKeyObj.sign(md);
    return forge.util.encode64(signature);
}

// 使用公钥验证签名
function verifySignature(publicKey: string, data: string, signature: string): boolean {
    const publicKeyObj = forge.pki.publicKeyFromPem(publicKey);
    const md = forge.md.sha256.create();
    md.update(data, "utf8");
    const decodedSignature = forge.util.decode64(signature);
    return publicKeyObj.verify(md.digest().bytes(), decodedSignature);
}

// 主函数
function main() {
    const nickname = "Zhaoyu";

    // Step 1: 生成 RSA 公私钥对
    const { publicKey, privateKey } = generateKeyPair();
    console.log("Public Key:", publicKey);
    console.log("Private Key:", privateKey);

    // Step 2: 寻找符合 POW 的 nonce 和哈希值
    console.log("Finding nonce...");
    const { nonce, hash } = findNonce(nickname);
    console.log("Found nonce:", nonce);
    console.log("Hash:", hash);

    // Step 3: 用私钥对 "昵称 + nonce" 签名
    const dataToSign = nickname + nonce;
    const signature = signData(privateKey, dataToSign);
    console.log("Signature:", signature);

    // Step 4: 用公钥验证签名
    const isValid = verifySignature(publicKey, dataToSign, signature);
    console.log("Is signature valid?", isValid);
}

main();
