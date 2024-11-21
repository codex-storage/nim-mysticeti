import std/hashes
import ../examples

type MockHash* = distinct hashes.Hash

func hash*(_: type MockHash, bytes: openArray[byte]): MockHash =
  MockHash(bytes.hash)

func `==`*(a, b: MockHash): bool {.borrow.}
func `$`*(hash: MockHash): string {.borrow.}

proc example*(_: type MockHash): MockHash =
  MockHash.hash(seq[byte].example)
