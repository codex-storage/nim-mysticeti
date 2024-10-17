import ../basics
import ../committee
import ../blocks
import ./slots

type
  Rounds*[Hashing] = object
    first*, last*: Round[Hashing]
  Round*[Hashing] = ref object
    number: uint64
    previous, next: ?Round[Hashing]
    slots: seq[ProposerSlot[Hashing]]

func wave*(rounds: Rounds): auto =
  # A wave consists of 3 rounds: proposing -> voting -> certifying
  type Round = typeof(rounds.last)
  let certifying = rounds.last
  if voting =? certifying.previous:
    if proposing =? voting.previous:
      return some (proposing, voting, certifying)
  none (Round, Round, Round)

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

func `[]`*(round: Round, member: CommitteeMember): auto =
  round.slots[int(member)]

iterator members*(round: Round): CommitteeMember =
  let length = round.slots.len
  let offset = (round.number mod length.uint64).int
  for index in 0..<length:
    yield CommitteeMember((offset + index) mod length)

iterator slots*(round: Round): auto =
  for member in round.members:
    yield round[member]

iterator proposals*(round: Round): auto =
  for slot in round.slots:
    for proposal in slot.proposals:
      yield proposal

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

func find*(round: Round, blockId: BlockId): auto =
  if found =? round.find(blockId.round):
    let slot = found[blockId.author]
    for proposal in slot.proposals:
      let blck = proposal.blck
      if blck.id == blockId:
        return some blck

func findAnchor*(round: Round): auto =
  var next = round.find(round.number + 3)
  while current =? next:
    for slot in current.slots:
      if slot.status in [SlotStatus.undecided, SlotStatus.commit]:
        return some slot
    next = current.next

func createNext*(round: Round): auto =
  assert round.next.isNone
  let next = Round.new(round.number + 1, round.slots.len)
  next.previous = some round
  round.next = some next
  next

func add*(round: Round, blck: Block): auto =
  if slot =? round[blck.author]:
    slot.add(blck)
