import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { TokenCreated } from "../generated/schema"
import { TokenCreated as TokenCreatedEvent } from "../generated/Factory/Factory"
import { handleTokenCreated } from "../src/factory"
import { createTokenCreatedEvent } from "./factory-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let tokenAddr = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let creator = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let symbol = "Example string value"
    let totalSupply = BigInt.fromI32(234)
    let perMint = BigInt.fromI32(234)
    let price = BigInt.fromI32(234)
    let newTokenCreatedEvent = createTokenCreatedEvent(
      tokenAddr,
      creator,
      symbol,
      totalSupply,
      perMint,
      price
    )
    handleTokenCreated(newTokenCreatedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("TokenCreated created and stored", () => {
    assert.entityCount("TokenCreated", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "TokenCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "tokenAddr",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "TokenCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "creator",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "TokenCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "symbol",
      "Example string value"
    )
    assert.fieldEquals(
      "TokenCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "totalSupply",
      "234"
    )
    assert.fieldEquals(
      "TokenCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "perMint",
      "234"
    )
    assert.fieldEquals(
      "TokenCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "price",
      "234"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
