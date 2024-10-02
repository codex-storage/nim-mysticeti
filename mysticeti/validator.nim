import ./basics
import ./signing
import ./committee
import ./blocks

type
  Validator*[Signing, Hashing] = ref object
    identity: Identity[Signing]
    committee: Committee[Signing]
    membership: CommitteeMember
    first, last: Round[Signing, Hashing]
  Round[Signing, Hashing] = ref object
    number: uint64
    previous, next: ?Round[Signing, Hashing]
    slots: seq[ProposerSlot[Signing, Hashing]]
  ProposerSlot[Signing, Hashing] = ref object
    proposals: seq[Proposal[Signing, Hashing]]
    skippedBy: Stake
    status: SlotStatus
  Proposal[Signing, Hashing] = ref object
    blck: Block[Signing, Hashing]
    certifiedBy: Stake
    certificates: seq[BlockId[Signing, Hashing]]
  SlotStatus* {.pure.} = enum
    undecided
    skip
    commit
    committed

func new*(T: type Round, number: uint64, committee: Committee): T =
  type Slot = ProposerSlot[T.Signing, T.Hashing]
  let slots = newSeqWith(committee.size, Slot.new())
  T(number: number, slots: slots)

func new*(T: type Validator; identity: Identity, committee: Committee): ?!T =
  let round = Round[T.Signing, T.Hashing].new(0, committee)
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

func init(_: type Proposal, blck: Block): auto =
  Proposal[Block.Signing, Block.Hashing](blck: blck)

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
        slot.skippedBy += validator.committee.stake(supporter.author)
      if slot.skippedBy > 2/3:
        slot.status = SlotStatus.skip

func updateCertified(validator: Validator, certificate: Block) =
  without (proposing, voting, _) =? validator.wave:
    return
  for proposerSlot in proposing.slots:
    for proposal in proposerSlot.proposals:
      var support: Stake
      for voterSlot in voting.slots:
        for vote in voterSlot.proposals:
          if proposal.blck.id in vote.blck.parents:
            if vote.blck.id in certificate.parents:
              support += validator.committee.stake(vote.blck.author)
      if support > 2/3:
        proposal.certifiedBy += validator.committee.stake(certificate.author)
        proposal.certificates.add(certificate.id)
      if proposal.certifiedBy > 2/3:
        proposerSlot.status = SlotStatus.commit

proc propose*(validator: Validator, transactions: seq[Transaction]): auto =
  assert validator.last[validator.membership].proposals.len == 0
  var parents: seq[BlockId[Validator.Signing, Validator.Hashing]]
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
  validator.last[validator.membership].proposals.add(Proposal.init(blck))
  validator.updateCertified(blck)
  validator.identity.sign(blck)

func receive*(validator: Validator, signed: SignedBlock) =
  validator.last[signed.blck.author].proposals.add(Proposal.init(signed.blck))
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

func certifiedProposal(slot: ProposerSlot): auto =
  if slot.status in [SlotStatus.commit, SlotStatus.committed]:
    for proposal in slot.proposals:
      if proposal.certifiedBy > 2/3:
        return some proposal

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
        slotProposal.certifiedBy = anchorProposal.certifiedBy
        slot.status = SlotStatus.commit
        return
      without parentBlock =? round.searchBackwards(parent):
        discard
      todo.add(parentBlock.parents)
  slot.status = SlotStatus.skip

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
        slot.status = SlotStatus.committed
        without proposal =? slot.certifiedProposal:
          raiseAssert "slot state is 'commit', but no proposal is certified"
        yield proposal.blck
    if not done:
      validator.remove(round)
      current = round.next
