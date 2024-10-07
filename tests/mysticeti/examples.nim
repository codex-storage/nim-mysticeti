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
  Identity[T.Signing].example.identifier

proc example*(T: type CommitteeMember): T =
  CommitteeMember(int.example)

proc example*(T: type Hash): T =
  T.Hashing.hash(seq[byte].example)

proc example*(T: type BlockId): T =
  let author = CommitteeMember.example
  let round = uint64.example
  let hash = Hash[T.Hashing].example
  BlockId.new(author, round, hash)

proc example*(T: type Block): T =
  let author = CommitteeMember.example
  let round = uint64.example
  let parents = seq[BlockId[T.Hashing]].example
  let transactions = seq[Transaction].example
  Block.new(author, round, parents, transactions)

proc example*[T](_: type seq[T], length=0..10): seq[T] =
  let size = rand(length)
  newSeqWith(size, T.example)

proc example*[len: static int, T](_: type array[len, T]): array[len, T] =
  for index in result.low..result.high:
    result[index] = T.example
