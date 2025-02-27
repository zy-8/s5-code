import {createPublicClient, http, webSocket} from 'viem'
import { mainnet } from 'viem/chains'


export const publicClient = createPublicClient({
    chain: mainnet,
    transport: http()
})

export const publicWsClient = createPublicClient({
    chain: mainnet,
    transport: webSocket('wss://ethereum-rpc.publicnode.com')
})