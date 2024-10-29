import ../basics
import ./round

export round

type Rounds*[Signing, Hashing] = object
  oldest, latest: Round[Signing, Hashing]

func init*(T: type Rounds, slots: int, start: uint64 = 0): T =
  let round = Round[T.Signing, T.Hashing].new(start, slots)
  T(oldest: round, latest: round)

func oldest*(rounds: Rounds): auto =
  rounds.oldest

func latest*(rounds: Rounds): auto =
  rounds.latest

func wave*(rounds: Rounds): auto =
  # A wave consists of 3 rounds: proposing -> voting -> certifying
  let certifying = rounds.latest
  if voting =? certifying.previous:
    if proposing =? voting.previous:
      return some (proposing, voting, certifying)

func addNewRound*(rounds: var Rounds) =
  rounds.latest = Round[Rounds.Signing, Rounds.Hashing].new(rounds.latest)

func removeOldestRound*(rounds: var Rounds) =
  assert rounds.oldest.next.isSome
  let next = !rounds.oldest.next
  rounds.oldest.remove()
  rounds.oldest = next
