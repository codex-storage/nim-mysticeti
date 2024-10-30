import ./members
import ./committee

type Voting* = object
  voted: seq[CommitteeMember]
  stake: Stake

func add*(voting: var Voting, member: CommitteeMember, stake: Stake) =
  if member notin voting.voted:
    voting.voted.add(member)
    voting.stake += stake

func stake*(voting: Voting): Stake =
  voting.stake
