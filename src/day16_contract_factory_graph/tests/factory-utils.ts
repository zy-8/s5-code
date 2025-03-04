import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import { TokenCreated, TokenMinted } from "../generated/Factory/Factory"

export function createTokenCreatedEvent(
  tokenAddr: Address,
  creator: Address,
  symbol: string,
  totalSupply: BigInt,
  perMint: BigInt,
  price: BigInt
): TokenCreated {
  let tokenCreatedEvent = changetype<TokenCreated>(newMockEvent())

  tokenCreatedEvent.parameters = new Array()

  tokenCreatedEvent.parameters.push(
    new ethereum.EventParam("tokenAddr", ethereum.Value.fromAddress(tokenAddr))
  )
  tokenCreatedEvent.parameters.push(
    new ethereum.EventParam("creator", ethereum.Value.fromAddress(creator))
  )
  tokenCreatedEvent.parameters.push(
    new ethereum.EventParam("symbol", ethereum.Value.fromString(symbol))
  )
  tokenCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "totalSupply",
      ethereum.Value.fromUnsignedBigInt(totalSupply)
    )
  )
  tokenCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "perMint",
      ethereum.Value.fromUnsignedBigInt(perMint)
    )
  )
  tokenCreatedEvent.parameters.push(
    new ethereum.EventParam("price", ethereum.Value.fromUnsignedBigInt(price))
  )

  return tokenCreatedEvent
}

export function createTokenMintedEvent(
  tokenAddr: Address,
  creator: Address,
  amount: BigInt
): TokenMinted {
  let tokenMintedEvent = changetype<TokenMinted>(newMockEvent())

  tokenMintedEvent.parameters = new Array()

  tokenMintedEvent.parameters.push(
    new ethereum.EventParam("tokenAddr", ethereum.Value.fromAddress(tokenAddr))
  )
  tokenMintedEvent.parameters.push(
    new ethereum.EventParam("creator", ethereum.Value.fromAddress(creator))
  )
  tokenMintedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return tokenMintedEvent
}
