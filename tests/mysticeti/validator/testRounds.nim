import ../basics
import mysticeti
import mysticeti/validator/rounds

suite "Validator Rounds":

  type Rounds = rounds.Rounds[MockHashing]

  test "members are ordered round-robin for each round":
    var rounds = Rounds.new(4)
    check toSeq(rounds.last.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))
    rounds.addNextRound()
    check toSeq(rounds.last.members) == @[1, 2, 3, 0].mapIt(CommitteeMember(it))
    rounds.addNextRound()
    check toSeq(rounds.last.members) == @[2, 3, 0, 1].mapIt(CommitteeMember(it))
    rounds.addNextRound()
    check toSeq(rounds.last.members) == @[3, 0, 1, 2].mapIt(CommitteeMember(it))
    rounds.addNextRound()
    check toSeq(rounds.last.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))
