import ./basics
import ./signing

type
  Committee*[Signing] = ref object
    stakes: Table[Identifier[Signing], Stake]
  Stake* = float64

func new*(_: type Committee, stakes: openArray[(Identifier, Stake)]): auto =
  Committee[Identifier.Signing](stakes: stakes.toTable)

func stake*(committee: Committee, identifier: Identifier): Stake =
  committee.stakes.getOrDefault(identifier)
