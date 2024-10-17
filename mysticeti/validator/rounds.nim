import ../basics
import ./slots

type
  Rounds*[Hashing] = object
    first*, last*: Round[Hashing]
  Round*[Hashing] = ref object
    number: uint64
    previous*, next*: ?Round[Hashing]
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

func createNext*(round: Round): auto =
  assert round.next.isNone
  let next = Round.new(round.number + 1, round.slots.len)
  next.previous = some round
  round.next = some next
  next

func number*(round: Round): uint64 =
  round.number
