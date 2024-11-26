import ../basics
import ../blocks
import ../committee
import ./slots

type Round*[Dependencies] = ref object
  number: uint64
  previous, next: ?Round[Dependencies]
  slots: seq[ProposerSlot[Dependencies]]

func new*(T: type Round, number: uint64, slots: int): T =
  assert slots > 0
  type Slot = ProposerSlot[T.Dependencies]
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

func primaryProposer*(round: Round): CommitteeMember =
  CommitteeMember((round.number mod round.slots.len.uint64).int)

iterator proposers*(round: Round): CommitteeMember =
  let length = round.slots.len
  let offset = (round.number mod length.uint64).int
  for index in 0..<length:
    yield CommitteeMember((offset + index) mod length)

iterator slots*(round: Round): auto =
  for member in round.proposers:
    yield round[member]

iterator proposals*(round: Round): auto =
  for slot in slots(round):
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
      let signedBlock = proposal.signedBlock
      if signedBlock.blck.id == blockId:
        return some signedBlock

func findAnchor*(round: Round): auto =
  var next = round.find(round.number + 3)
  while current =? next:
    for slot in slots(current):
      if slot.status in [SlotStatus.undecided, SlotStatus.commit]:
        return some slot
    next = current.next

func addProposal*(round: Round, signedBlock: SignedBlock): auto =
  let blck = signedBlock.blck
  assert blck.round == round.number
  round[blck.author].addProposal(signedBlock)

func remove*(round: Round) =
  if previous =? round.previous:
    previous.next = round.next
  if next =? round.next:
    next.previous = round.previous
  round.next = none Round
  round.previous = none Round
