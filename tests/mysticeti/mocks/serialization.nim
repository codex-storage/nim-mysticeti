import std/json
import mysticeti
import ./transacting

type MockSerialization* = object

proc `%`*(member: CommitteeMember): JsonNode =
  %member.int

proc `%`*(id: BlockId): JsonNode =
  %*{
    "author": id.author,
    "round": id.round,
    "hash": $id.hash
  }

proc `%`*(transaction: MockTransacting.Transaction): JsonNode =
  %*{
    "nonce": transaction.nonce
  }

proc `%`*(blck: Block): JsonNode =
  %*{
    "author": blck.author,
    "round": blck.round,
    "parents": blck.parents,
    "transactions": blck.transactions
  }

func toBytes*(_: type MockSerialization, blck: Block): seq[byte] =
  let json = %blck
  cast[seq[byte]]($json)
