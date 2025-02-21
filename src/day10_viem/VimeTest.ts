import {publicClient} from "./client";
import {abi} from "./abi";

async function getBlockNumber(): Promise<bigint> {
    const blockNumber = await publicClient.getBlockNumber()
    return blockNumber;
}

/**
 * 读取tokenID的持有者地址
 * @param tokenId
 */
async function getNFTInfo(nftAddress: `0x${string}`,tokenId: bigint) {
    try {
        // 并行请求 owner 和 tokenURI
        const [owner, tokenURI] = await Promise.all([
            publicClient.readContract({
                address: nftAddress,
                abi,
                functionName: 'ownerOf',
                args: [tokenId]
            }),
            publicClient.readContract({
                address:nftAddress,
                abi,
                functionName: 'tokenURI',
                args: [tokenId]
            })
        ])

        return {
            tokenId,
            owner,
            tokenURI
        }
    } catch (error) {
        console.error('Error getting NFT info:', error)
        throw error
    }
}
const main = async () => {
    // 3. Consume an action!
    try {
        const blockNumber = await getBlockNumber()
        console.log('Current block number:', blockNumber)
        //读取指定nft信息
        const result  = await getNFTInfo('0x0483b0dfc6c78062b9e999a82ffb795925381415',BigInt(8))
        console.log('Result:', result);
    } catch (error) {
        console.error('Error:', error)
    }

}
main();