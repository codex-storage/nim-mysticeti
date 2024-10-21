import ../basics
import ../blocks
import ../committee
import ./slots

type Round*[Hashing] = ref object
  number: uint64
  previous, next: ?Round[Hashing]
  slots: seq[ProposerSlot[Hashing]]

func new*(T: type Round, number: uint64, slots: int): T =
  type Slot = ProposerSlot[T.Hashing]
  let slots = newSeqWith(slots, Slot.new())
  T(number: number, slots: slots)

func new*(_: type Round, previous: Round): Round =
  assert previous.next.isNone
  result = Round.new(previous.number + 1, previous.slots.len)
  result.previous = some previous
  previous.next = some result

func number*(round: Round): uint64 =
  round.number

func previous*(round: Round): auto =
  round.previous

func next*(round: Round): auto =
  round.next

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

func remove*(round: Round) =
  if previous =? round.previous:
    previous.next = round.next
  if next =? round.next:
    next.previous = round.previous
  round.next = none Round
  round.previous = none Round

func addProposal*(round: Round, blck: Block): auto =
  round[blck.author].addProposal(blck)
