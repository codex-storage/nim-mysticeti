import std/random
import mysticeti/dependencies/transacting

type
  MockTransaction = object
    nonce: int
  MockTransacting* = Transacting[MockTransaction]

proc nonce*(transaction: MockTransaction): int =
  transaction.nonce

proc example*(_: type MockTransaction): MockTransaction =
  MockTransaction(nonce: rand(int))
