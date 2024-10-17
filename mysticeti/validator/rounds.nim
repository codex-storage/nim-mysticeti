import ../basics
import ./slots

type
  Rounds*[Hashing] = object
    first*, last*: Round[Hashing]
  Round*[Hashing] = ref object
    number: uint64
    previous, next: ?Round[Hashing]
    slots*: seq[ProposerSlot[Hashing]]

func remove*(rounds: var Rounds, round: Round) =
  if previous =? round.previous:
    previous.next = round.next
  else:
    rounds.first = !round.next
  if next =? round.next:
    next.previous = round.previous
  else:
    rounds.last = !round.previous

func new*(T: type Round, number: uint64, slots: int): T =
  type Slot = ProposerSlot[T.Hashing]
  let slots = newSeqWith(slots, Slot.new())
  T(number: number, slots: slots)

func previous*(round: Round): auto =
  round.previous

func next*(round: Round): auto =
  round.next

func number*(round: Round): uint64 =
  round.number

func find*(round: Round, number: uint64): ?Round =
  var current = round
  while true:
    if current.number == number:
      return some current
    elif current.number < number:
      without next =? current.next:
        return none Round
      current = next
    else:
      without previous =? current.previous:
        return none Round
      current = previous

func createNext*(round: Round): auto =
  assert round.next.isNone
  let next = Round.new(round.number + 1, round.slots.len)
  next.previous = some round
  round.next = some next
  next
