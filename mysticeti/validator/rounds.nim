import ../basics
import ./round

export round

type Rounds*[Dependencies] = object
  oldest, latest: Round[Dependencies]

func init*(T: type Rounds, slots: int, start: uint64 = 0): T =
  let round = Round[T.Dependencies].new(start, slots)
  T(oldest: round, latest: round)

func oldest*(rounds: Rounds): auto =
  rounds.oldest

func latest*(rounds: Rounds): auto =
  rounds.latest

func addNewRound*(rounds: var Rounds) =
  rounds.latest = Round[Rounds.Dependencies].new(rounds.latest)

func removeOldestRound*(rounds: var Rounds) =
  assert rounds.oldest.next.isSome
  let next = !rounds.oldest.next
  rounds.oldest.remove()
  rounds.oldest = next
