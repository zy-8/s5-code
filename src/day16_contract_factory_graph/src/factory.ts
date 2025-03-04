import {
  TokenCreated as TokenCreatedEvent,
  TokenMinted as TokenMintedEvent
} from "../generated/Factory/Factory"
import { TokenCreated, TokenMinted } from "../generated/schema"

export function handleTokenCreated(event: TokenCreatedEvent): void {
  let entity = new TokenCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.tokenAddr = event.params.tokenAddr
  entity.creator = event.params.creator
  entity.symbol = event.params.symbol
  entity.totalSupply = event.params.totalSupply
  entity.perMint = event.params.perMint
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTokenMinted(event: TokenMintedEvent): void {
  let entity = new TokenMinted(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.tokenAddr = event.params.tokenAddr
  entity.creator = event.params.creator
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
