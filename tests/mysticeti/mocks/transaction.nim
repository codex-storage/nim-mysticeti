import std/random

type
  MockTransaction* = object
    nonce: int

proc nonce*(transaction: MockTransaction): int =
  transaction.nonce

proc example*(_: type MockTransaction): MockTransaction =
  MockTransaction(nonce: rand(int))
