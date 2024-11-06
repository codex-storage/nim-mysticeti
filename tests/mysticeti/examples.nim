import std/random
import std/sequtils
import mysticeti
import mysticeti/blocks
import mysticeti/hashing

proc example*(T: type SomeInteger): T =
  rand(T)

proc example*(_: type Transaction): Transaction =
  discard

proc example*(T: type Identity): T =
  T.init()

proc example*(T: type Identifier): T =
  Identity[T.Dependencies].example.identifier

proc example*(T: type CommitteeMember): T =
  CommitteeMember(int.example)

proc example*(T: type Hash): T =
  T.hash(seq[byte].example)

proc example*(T: type BlockId): T =
  let author = CommitteeMember.example
  let round = uint64.example
  let hash = Hash[T.Dependencies].example
  T.new(author, round, hash)

proc example*(
  T: type Block,
  author = CommitteeMember.example,
  round = uint64.example
): T =
  let parents = seq[BlockId[T.Dependencies]].example
  let transactions = seq[Transaction].example
  T.new(author, round, parents, transactions)

proc example*(
  T: type SignedBlock,
  author = CommitteeMember.example,
  round = uint64.example
): T =
  let identity = Identity[T.Dependencies].example
  let blck = Block[T.Dependencies].example(author = author, round = round)
  identity.sign(blck)

proc example*[T](_: type seq[T], length=0..10): seq[T] =
  let size = rand(length)
  newSeqWith(size, T.example)

proc example*[len: static int, T](_: type array[len, T]): array[len, T] =
  for index in result.low..result.high:
    result[index] = T.example
