import ./basics
import ./signing
import ./committee
import ./blocks
import ./validator/slots

export slots

type
  Validator*[Signing, Hashing] = ref object
    identity: Identity[Signing]
    committee: Committee[Signing]
    membership: CommitteeMember
    first, last: Round[Hashing]
  Round[Hashing] = ref object
    number: uint64
    previous, next: ?Round[Hashing]
    slots: seq[ProposerSlot[Hashing]]

func new*(T: type Round, number: uint64, committee: Committee): T =
  type Slot = ProposerSlot[T.Hashing]
  let slots = newSeqWith(committee.size, Slot.new())
  T(number: number, slots: slots)

func new*(T: type Validator; identity: Identity, committee: Committee): ?!T =
  let round = Round[T.Hashing].new(0, committee)
  without membership =? committee.membership(identity.identifier):
    return T.failure "identity is not a member of the committee"
  success T(
    identity: identity,
    committee: committee,
    membership: membership,
    first: round,
    last: round
  )

func `[]`(round: Round, member: CommitteeMember): auto =
  round.slots[int(member)]

func add(round: Round, blck: Block): auto =
  if slot =? round[blck.author]:
    slot.add(blck)

iterator proposals(round: Round): auto =
  for slot in round.slots:
    for proposal in slot.proposals:
      yield proposal

func identifier*(validator: Validator): auto =
  validator.identity.identifier

func membership*(validator: Validator): CommitteeMember =
  validator.membership

func round*(validator: Validator): uint64 =
  validator.last.number

func wave(validator: Validator): auto =
  # A wave consists of 3 rounds: proposing -> voting -> certifying
  type Round = typeof(validator.last)
  let certifying = validator.last
  if voting =? certifying.previous:
    if proposing =? voting.previous:
      return some (proposing, voting, certifying)
  none (Round, Round, Round)

func nextRound*(validator: Validator) =
  type Round = typeof(validator.last)
  let previous = validator.last
  let next = Round.new(previous.number + 1, validator.committee)
  next.previous = some previous
  previous.next = some next
  validator.last = next

func remove(validator: Validator, round: Round) =
  if previous =? round.previous:
    previous.next = round.next
  else:
    validator.first = !round.next
  if next =? round.next:
    next.previous = round.previous
  else:
    validator.last = !round.previous

func skips(blck: Block, round: uint64, author: CommitteeMember): bool =
  for parent in blck.parents:
    if parent.round == round and parent.author == author:
      return false
  true

func updateSkipped(validator: Validator, supporter: Block) =
  if previous =? validator.last.previous:
    for (member, slot) in previous.slots.pairs:
      if supporter.skips(previous.number, CommitteeMember(member)):
        let stake = validator.committee.stake(supporter.author)
        slot.skipBy(stake)

func updateCertified(validator: Validator, certificate: Block) =
  without (proposing, voting, _) =? validator.wave:
    return
  for proposal in proposing.proposals:
    var support: Stake
    for vote in voting.proposals:
      if proposal.blck.id in vote.blck.parents:
        if vote.blck.id in certificate.parents:
          support += validator.committee.stake(vote.blck.author)
    if support > 2/3:
      let stake = validator.committee.stake(certificate.author)
      proposal.certifyBy(certificate.id, stake)

proc propose*(validator: Validator, transactions: seq[Transaction]): auto =
  assert validator.last[validator.membership].proposals.len == 0
  var parents: seq[BlockId[Validator.Hashing]]
  if previous =? validator.last.previous:
    for slot in previous.slots:
      if slot.proposals.len == 1:
        parents.add(slot.proposals[0].blck.id)
  let blck = Block.new(
    author = validator.membership,
    round = validator.last.number,
    parents = parents,
    transactions = transactions
  )
  validator.last.add(blck)
  validator.updateCertified(blck)
  validator.identity.sign(blck)

func receive*(validator: Validator, signed: SignedBlock) =
  validator.last.add(signed.blck)
  validator.updateSkipped(signed.blck)
  validator.updateCertified(signed.blck)

func round(validator: Validator, number: uint64): auto =
  var round = validator.last
  while round.number > number and previous =? round.previous:
    round = previous
  if round.number == number:
    return some round

func status*(validator: Validator, blck: Block): ?SlotStatus =
  if round =? round(validator, blck.round):
    some round[blck.author].status
  else:
    none SlotStatus

func status*(validator: Validator, proposal: SignedBlock): ?SlotStatus =
  validator.status(proposal.blck)

func findAnchor(validator: Validator, round: Round): auto =
  var next = round.next.?next.?next
  while current =? next:
    for member in validator.committee.ordered(current.number):
      let slot = current[member]
      if slot.status in [SlotStatus.undecided, SlotStatus.commit]:
        return some slot
    next = current.next

func searchBackwards(round: Round, blockId: BlockId): auto =
  var current = round
  while current.number > blockId.round and previous =? current.previous:
    current = previous
  if current.number == blockId.round:
    let slot = current[blockId.author]
    for proposal in slot.proposals:
      let blck = proposal.blck
      if blck.id == blockId:
        return some blck

func updateIndirect(validator: Validator, slot: ProposerSlot, round: Round) =
  without anchor =? validator.findAnchor(round):
    return
  without anchorProposal =? anchor.certifiedProposal:
    return
  var todo = anchorProposal.blck.parents
  while todo.len > 0:
    let parent = todo.pop()
    if parent.round < round.number + 2:
      continue
    for slotProposal in slot.proposals:
      if parent in slotProposal.certificates:
        slotProposal.certify(anchorProposal)
        return
      without parentBlock =? round.searchBackwards(parent):
        discard
      todo.add(parentBlock.parents)
  slot.skip()

iterator committed*(validator: Validator): auto =
  var done = false
  var current = some validator.first
  while not done and round =? current:
    for member in validator.committee.ordered(round.number):
      let slot = round[member]
      if slot.status == SlotStatus.undecided:
        validator.updateIndirect(slot, round)
      case slot.status
      of SlotStatus.undecided:
        done = true
        break
      of SlotStatus.skip, SlotStatus.committed:
        discard
      of SlotStatus.commit:
        yield slot.commit()
    if not done:
      validator.remove(round)
      current = round.next
