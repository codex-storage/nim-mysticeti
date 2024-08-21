import std/hashes
import mysticeti/hashing

type
  MockHash = distinct hashes.Hash
  MockHashing* = Hashing[MockHash]

func hash*(_: type MockHash, bytes: openArray[byte]): MockHash =
  MockHash(bytes.hash)

func `==`*(a, b: MockHash): bool {.borrow.}
func `$`*(hash: MockHash): string {.borrow.}
