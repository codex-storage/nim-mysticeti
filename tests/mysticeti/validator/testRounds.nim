import ../basics
import mysticeti/validator/rounds

suite "List of Validator Rounds":

  type Rounds = rounds.Rounds[MockSigning, MockHashing]
  type Round = rounds.Round[MockSigning, MockHashing]

  test "has a single round initially":
    let rounds = Rounds.init(slots = 4)
    check rounds.oldest.previous == none Round
    check rounds.oldest.next == none Round
    check rounds.oldest == rounds.latest

  test "initial round has number 0 by default":
    let rounds = Rounds.init(slots = 4)
    check rounds.oldest.number == 0

  test "initial round can have a specific number":
    let rounds = Rounds.init(slots = 4, start = 42)
    check rounds.oldest.number == 42

  test "new rounds can be added":
    var rounds = Rounds.init(slots = 4)
    rounds.addNewRound()
    check rounds.oldest.number == 0
    check rounds.oldest.previous == none Round
    check rounds.oldest.next == some rounds.latest
    check rounds.latest.number == 1
    check rounds.latest.previous == some rounds.oldest
    check rounds.latest.next == none Round

  test "oldest round can be removed":
    var rounds = Rounds.init(slots = 4, start = 42)
    rounds.addNewRound()
    rounds.addNewRound()
    rounds.addNewRound()
    rounds.removeOldestRound()
    check rounds.oldest.number == 43
    check rounds.latest.number == 45
    rounds.removeOldestRound()
    check rounds.oldest.number == 44
    check rounds.latest.number == 45
    rounds.removeOldestRound()
    check rounds.oldest.number == 45
    check rounds.oldest == rounds.latest

  test "the last remaining round can not be removed":
    var rounds = Rounds.init(slots = 4, start = 42)
    rounds.addNewRound()
    rounds.removeOldestRound()
    expect Defect:
      rounds.removeOldestRound()

  test "a wave consists of the last three rounds":
    var rounds = Rounds.init(slots = 4)
    rounds.addNewRound()
    check rounds.wave.isNone
    rounds.addNewRound()
    var wave: (Round, Round, Round)
    wave = !rounds.wave()
    check wave[0].number == 0
    check wave[1].number == 1
    check wave[2].number == 2
    rounds.addNewRound()
    wave = !rounds.wave()
    check wave[0].number == 1
    check wave[1].number == 2
    check wave[2].number == 3
