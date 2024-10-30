import ../basics
import mysticeti
import mysticeti/committee

suite "Committee Voting":

  test "by default 0 stake has voted":
    var voting: Voting
    check voting.stake == 0

  test "when a member adds a vote, it add its stake to the total":
    var voting: Voting
    voting.add(CommitteeMember(0), 1/8)
    check voting.stake == 1/8
    voting.add(CommitteeMember(1), 1/2)
    check voting.stake == 5/8
    voting.add(CommitteeMember(3), 1/8)
    check voting.stake == 3/4

  test "votes are only counted once":
    var voting: Voting
    voting.add(CommitteeMember(0), 1/8)
    check voting.stake == 1/8
    voting.add(CommitteeMember(0), 1/8)
    check voting.stake == 1/8
