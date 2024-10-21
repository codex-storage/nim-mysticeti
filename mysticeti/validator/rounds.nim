import ../basics
import ../committee
import ../blocks
import ./slots

type Round*[Hashing] = ref object
  number: uint64
  previous, next: ?Round[Hashing]
  slots: seq[ProposerSlot[Hashing]]

func new*(T: type Round, number: uint64, slots: int): T =
  type Slot = ProposerSlot[T.Hashing]
  let slots = newSeqWith(slots, Slot.new())
  T(number: number, slots: slots)

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

func add*(round: Round, blck: Block): auto =
  round[blck.author].add(blck)

type Rounds*[Hashing] = object
  oldest, latest: Round[Hashing]

func new*(T: type Rounds, slots: int, start: uint64 = 0): T =
  let round = Round[T.Hashing].new(start, slots)
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
  let previous = rounds.latest
  let next = Round[Rounds.Hashing].new(previous.number + 1, previous.slots.len)
  next.previous = some previous
  previous.next = some next
  rounds.latest = next

func removeOldestRound*(rounds: var Rounds) =
  assert rounds.oldest.previous.isNone
  assert rounds.oldest.next.isSome
  type Round = typeof(rounds.oldest)
  let oldest = rounds.oldest
  let next = !oldest.next
  next.previous = none Round
  oldest.next = none Round
  rounds.oldest = next
