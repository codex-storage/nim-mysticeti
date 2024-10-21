import ../basics
import mysticeti
import mysticeti/validator/rounds

suite "Validator Rounds":

  type Rounds = rounds.Rounds[MockHashing]

  test "members are ordered round-robin for each round":
    var rounds = Rounds.init(4)
    check toSeq(rounds.latest.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))
    rounds.addNewRound()
    check toSeq(rounds.latest.members) == @[1, 2, 3, 0].mapIt(CommitteeMember(it))
    rounds.addNewRound()
    check toSeq(rounds.latest.members) == @[2, 3, 0, 1].mapIt(CommitteeMember(it))
    rounds.addNewRound()
    check toSeq(rounds.latest.members) == @[3, 0, 1, 2].mapIt(CommitteeMember(it))
    rounds.addNewRound()
    check toSeq(rounds.latest.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))
