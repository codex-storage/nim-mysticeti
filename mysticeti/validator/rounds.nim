import ../basics
import ./slots

type Round*[Hashing] = ref object
  number: uint64
  previous*, next*: ?Round[Hashing]
  slots*: seq[ProposerSlot[Hashing]]

func new*(T: type Round, number: uint64, slots: int): T =
  type Slot = ProposerSlot[T.Hashing]
  let slots = newSeqWith(slots, Slot.new())
  T(number: number, slots: slots)

func number*(round: Round): uint64 =
  round.number
