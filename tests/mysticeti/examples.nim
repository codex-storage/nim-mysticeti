import std/random
import std/sequtils
import mysticeti

proc example*(_: type Transaction): Transaction =
  discard

proc example*[T](_: type seq[T], length=0..10): seq[T] =
  let size = rand(length)
  newSeqWith(size, T.example)
