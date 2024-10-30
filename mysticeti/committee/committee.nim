import ../basics
import ../signing
import ./members

type
  Committee*[Signing] = ref object
    members: seq[Identifier[Signing]]
    stakes: seq[Stake]
  Stake* = float64

func new*(_: type Committee, stakes: openArray[(Identifier, Stake)]): auto =
  var committee = Committee[Identifier.Signing]()
  for (member, stake) in stakes:
    committee.members.add(member)
    committee.stakes.add(stake)
  committee

func size*(committee: Committee): int =
  committee.members.len

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
