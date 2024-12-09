import std/random
import std/sequtils
import mysticeti
import mysticeti/blocks
import ./mocks

proc example*(T: type SomeInteger): T =
  rand(T)

proc example*(T: type CommitteeMember): T =
  CommitteeMember(int.example)

proc example*(T: type BlockId): T =
  let author = CommitteeMember.example
  let round = uint64.example
  let hash = T.Hash.example
  BlockId.new(author, round, hash)

proc example*(
  T: type Block,
  author = CommitteeMember.example,
  round = uint64.example
): T =
  type Transaction = T.Dependencies.Transaction
  let parents = seq[BlockId[T.Dependencies.Hash]].example
  let transactions = seq[Transaction].example
  T.new(author, round, parents, transactions)

proc example*(
  T: type SignedBlock,
  author = CommitteeMember.example,
  round = uint64.example
): T =
  let identity = T.Dependencies.Identity.example
  let blck = Block[T.Dependencies].example(author = author, round = round)
  blck.sign(identity)

proc example*[T](_: type seq[T], length=0..10): seq[T] =
  let size = rand(length)
  newSeqWith(size, T.example)

proc example*[len: static int, T](_: type array[len, T]): array[len, T] =
  for index in result.low..result.high:
    result[index] = T.example

proc example*(_: type MockHash): MockHash =
  MockHash.hash(seq[byte].example)

proc example*(T: type MockIdentity): T =
  T.init()

proc example*(T: type MockIdentifier): T =
  MockIdentity.example.identifier
