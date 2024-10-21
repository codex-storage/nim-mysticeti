import ../basics
import mysticeti
import mysticeti/validator/rounds

suite "Validator Round":

  type Round = rounds.Round[MockHashing]

  test "members are ordered round-robin for each round":
    var round: Round
    round = Round.new(0, 4)
    check toSeq(round.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))
    round = Round.new(1, 4)
    check toSeq(round.members) == @[1, 2, 3, 0].mapIt(CommitteeMember(it))
    round = Round.new(2, 4)
    check toSeq(round.members) == @[2, 3, 0, 1].mapIt(CommitteeMember(it))
    round = Round.new(3, 4)
    check toSeq(round.members) == @[3, 0, 1, 2].mapIt(CommitteeMember(it))
    round = Round.new(4, 4)
    check toSeq(round.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))
