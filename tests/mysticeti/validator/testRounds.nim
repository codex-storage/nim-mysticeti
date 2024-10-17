import ../basics
import mysticeti
import mysticeti/validator/rounds

suite "Validator Rounds":

  type Round = rounds.Round[MockHashing]

  test "members are ordered round-robin for each round":
    var round = Round.new(0, 4)
    check toSeq(round.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))
    round = round.createNext()
    check toSeq(round.members) == @[1, 2, 3, 0].mapIt(CommitteeMember(it))
    round = round.createNext()
    check toSeq(round.members) == @[2, 3, 0, 1].mapIt(CommitteeMember(it))
    round = round.createNext()
    check toSeq(round.members) == @[3, 0, 1, 2].mapIt(CommitteeMember(it))
    round = round.createNext()
    check toSeq(round.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))
