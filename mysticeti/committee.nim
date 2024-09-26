import ./basics
import ./signing

type
  Committee*[Signing] = ref object
    members: seq[Identifier[Signing]]
    stakes: seq[Stake]
  CommitteeMember* = distinct int
  Stake* = float64

proc `==`*(a, b: CommitteeMember): bool {.borrow.}
proc hash*(member: CommitteeMember): Hash {.borrow.}

func new*(_: type Committee, stakes: openArray[(Identifier, Stake)]): auto =
  var committee = Committee[Identifier.Signing]()
  for (member, stake) in stakes:
    committee.members.add(member)
    committee.stakes.add(stake)
  committee

func membership*(committee: Committee, identifier: Identifier): ?CommitteeMember =
  let index = committee.members.find(identifier)
  if index < 0:
    none CommitteeMember
  else:
    some CommitteeMember(index)

func stake*(committee: Committee, member: CommitteeMember): Stake =
  committee.stakes[int(member)]

func stake*(committee: Committee, identifier: Identifier): Stake =
  if member =? committee.membership(identifier):
    committee.stake(member)
  else:
    0

iterator ordered*(committee: Committee, round: uint64): CommitteeMember =
  let length = committee.members.len
  let offset = (round mod length.uint64).int
  for index in 0..<length:
    yield CommitteeMember((offset + index) mod length)
