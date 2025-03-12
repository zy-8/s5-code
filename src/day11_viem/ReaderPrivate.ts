import {createPublicClient, encodePacked, hexToBigInt, hexToNumber, http, keccak256, toHex} from "viem";
import {sepolia} from "viem/chains";


const publicClient = createPublicClient({
    chain: sepolia,
    transport: http()
})

async function getSlotData(index: bigint) {
    const slot0Data = await publicClient.getStorageAt({
        address: '0x3Cf6666FC6FAcc6036322E587b3e5CB9f5963BE5',
        slot: toHex(index)
    })
    return slot0Data;
}

interface LockInfo {
    user: string;
    startTime: Date;
    amount: bigint;
}

/**
 * //错误写法
 *     //encodePacked(["uint256"], [BigInt(0)]) 会输出一个长度为 32 字节的字节流，表示 0 在内存中的 256 位表示。
 *     // toHex(0) 会输出字符串 "0x0"，这是数字 0 的十六进制表示
 *     const baseStorageSlot = hexToBigInt(keccak256(toHex(0)));
 *     //"0x0000000000000000000000000000000000000000000000000000000000000000"
 *     const t1 = encodePacked(["uint256"], [BigInt(0)])
 *     //"0x0"
 *     const t2 = toHex(0)
 *     //"0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563"
 *     const test1 = keccak256(encodePacked(["uint256"], [BigInt(0)]))
 *     //"0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a"
 *     const test2 = keccak256(toHex(0))
 */
async function main() {
    //读取solt槽0位置的长度 存储的是结构体长度
    const dataLength = hexToBigInt(await getSlotData(0n));
    console.log("Array Length:", dataLength);
    //计算数据存储起始位置 keccak256(slot 0)
    const baseSlot = BigInt(keccak256(encodePacked(["uint256"], [BigInt(0)])));
    const locksData: LockInfo[] = [];
    console.log("Base Storage Slot:", baseSlot);

    //获取solt0的全部结构体数据 i = 结构体存储位置
    for (let i = 0n; i < dataLength; i++) {
        //起始位 + 结构体存储位置
        const userAndTimeSlot = baseSlot + BigInt(i) * BigInt(2);
        const userAndStartTimeSlotData = await getSlotData(userAndTimeSlot);
        // 解析打包的数据
        // data 格式: [20 bytes address][8 bytes startTime]
        // address在后20字节
        const user = `0x${userAndStartTimeSlotData.slice(26, 66)}` as `0x${string}`; 
        // startTime在中间8字节
        const startTime = new Date(
            Number(hexToBigInt(`0x${userAndStartTimeSlotData.slice(10, 26)}`)) * 1000
        )
        // amount存储在下一个slot
        const amountSlot = userAndTimeSlot + BigInt(1)
        const amountSlotData = await getSlotData(amountSlot)
        const amount = BigInt(amountSlotData!);
        locksData.push({ user, startTime, amount });
    }

    for (const lock of locksData) {
        console.log("User:", lock.user);
        console.log("Start Time:", lock.startTime);
        console.log("Amount:", lock.amount.toString());
        console.log("------------------------");
    }
}

main();