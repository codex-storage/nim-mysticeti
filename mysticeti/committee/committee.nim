import ../basics
import ./members

type
  Committee*[Dependencies] = ref object
    members: seq[Identifier[Dependencies]]
    stakes: seq[Stake]
  Stake* = float64

func new*(T: type Committee, stakes: openArray[(Identifier, Stake)]): auto =
  var committee = T()
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
