import ../basics
import ./members

type
  Committee*[Identifier] = ref object
    members: seq[Identifier]
    stakes: seq[Stake]
  Stake* = float64

func new*[Identifier](
  _: type Committee,
  staking: openArray[(Identifier, Stake)]
): auto =
  var members: seq[Identifier]
  var stakes: seq[Stake]
  for (member, stake) in staking:
    members.add(member)
    stakes.add(stake)
  Committee[Identifier](members: members, stakes: stakes)

func size*(committee: Committee): int =
  committee.members.len

func membership*(
  committee: Committee,
  identifier: Committee.Identifier
): ?CommitteeMember =
  let index = committee.members.find(identifier)
  if index < 0:
    none CommitteeMember
  else:
    some CommitteeMember(index)

func stake*(committee: Committee, member: CommitteeMember): Stake =
  committee.stakes[int(member)]

func stake*(committee: Committee, identifier: Committee.Identifier): Stake =
  if member =? committee.membership(identifier):
    committee.stake(member)
  else:
    0
