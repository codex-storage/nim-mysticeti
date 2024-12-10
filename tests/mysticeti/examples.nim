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
  BlockId.init(author, round, hash)

proc example*(
  T: type SignedBlock,
  author = CommitteeMember.example,
  round = uint64.example
): T =
  let blck = T.Dependencies.Block.example(author = author, round = round)
  let signature = T.Dependencies.Signature.example
  SignedBlock[T.Dependencies].init(blck, signature)

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

proc example*(T: type MockSignature): T =
  MockIdentity.example.sign(MockHash.example)

proc example*(
  _: type MockBlock,
  author = CommitteeMember.example,
  round = uint64.example
): MockBlock =
  let parents = seq[BlockId[MockHash]].example
  let transactions = seq[MockTransaction].example
  MockBlock.new(author, round, parents, transactions)
