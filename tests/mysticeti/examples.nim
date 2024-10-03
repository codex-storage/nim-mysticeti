import std/random
import std/sequtils
import mysticeti

proc example*(_: type Transaction): Transaction =
  discard

proc example*(T: type Identity): T =
  T.init()

proc example*(T: type Identifier): T =
  Identity[T.Signing].example.identifier

proc example*[T](_: type seq[T], length=0..10): seq[T] =
  let size = rand(length)
  newSeqWith(size, T.example)

proc example*[len: static int, T](_: type array[len, T]): array[len, T] =
  for index in result.low..result.high:
    result[index] = T.example
