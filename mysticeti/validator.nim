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
    slots: Table[CommitteeMember, ProposerSlot[Signing, Hashing]]
  ProposerSlot[Signing, Hashing] = ref object
    proposal: Block[Signing, Hashing]
    skippedBy: Stake
    certifiedBy: Stake
    status: ProposalStatus
  ProposalStatus* {.pure.} = enum
    undecided
    skip
    commit
    committed

func new*(T: type Validator; identity: Identity, committee: Committee): ?!T =
  let round = Round[T.Signing, T.Hashing](number: 0)
  without membership =? committee.membership(identity.identifier):
    return T.failure "identity is not a member of the committee"
  success T(
    identity: identity,
    committee: committee,
    membership: membership,
    first: round,
    last: round
  )

func new*(_: type Round, number: uint64, previous: Round): auto =
  Round(number: number, previous: some previous)

func init(_: type ProposerSlot, proposal: Block): auto =
  ProposerSlot[Block.Signing, Block.Hashing](proposal: proposal)

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
  let previous = validator.last
  let next = Round.new(previous.number + 1, previous)
  validator.last = next
  previous.next = some next

func remove(validator: Validator, round: Round) =
  if previous =? round.previous:
    previous.next = round.next
  else:
    validator.first = !round.next
  if next =? round.next:
    next.previous = round.previous
  else:
    validator.last = !round.previous

func hasParent(blck: Block, round: uint64, author: CommitteeMember): bool =
  for parent in blck.parents:
    if parent.round == round and parent.author == author:
      return true
  false

func updateSkipped(validator: Validator, supporter: Block) =
  if previous =? validator.last.previous:
    for (id, slot) in previous.slots.mpairs:
      if not supporter.hasParent(previous.number, id):
        slot.skippedBy += validator.committee.stake(supporter.author)
      if slot.skippedBy > 2/3:
        slot.status = ProposalStatus.skip

func updateCertified(validator: Validator, certificate: Block) =
  without (proposing, voting, _) =? validator.wave:
    return
  for (proposerId, proposerSlot) in proposing.slots.mpairs:
    var support: Stake
    for (voterId, voterSlot) in voting.slots.pairs:
      if certificate.hasParent(voting.number, voterId):
        if voterSlot.proposal.hasParent(proposing.number, proposerId):
          support += validator.committee.stake(voterId)
    if support > 2/3:
      proposerSlot.certifiedBy += validator.committee.stake(certificate.author)
    if proposerSlot.certifiedBy > 2/3:
      proposerSlot.status = ProposalStatus.commit

proc propose*(validator: Validator, transactions: seq[Transaction]): auto =
  assert validator.membership notin validator.last.slots
  var parents: seq[BlockId[Validator.Signing, Validator.Hashing]]
  if previous =? validator.last.previous:
    for slot in previous.slots.values:
      parents.add(slot.proposal.id)
  let blck = Block.new(
    author = validator.membership,
    round = validator.last.number,
    parents = parents,
    transactions = transactions
  )
  validator.last.slots[validator.membership] = ProposerSlot.init(blck)
  validator.updateCertified(blck)
  validator.identity.sign(blck)

func receive*(validator: Validator, signed: SignedBlock) =
  validator.last.slots[signed.blck.author] = ProposerSlot.init(signed.blck)
  validator.updateSkipped(signed.blck)
  validator.updateCertified(signed.blck)

func round(validator: Validator, number: uint64): auto =
  var round = validator.last
  while round.number > number and previous =? round.previous:
    round = previous
  if round.number == number:
    return some round

func status*(validator: Validator, blck: Block): ?ProposalStatus =
  if round =? round(validator, blck.round) and blck.author in round.slots:
    let slot = round.slots[blck.author]
    some slot.status
  else:
    none ProposalStatus

func status*(validator: Validator, proposal: SignedBlock): ?ProposalStatus =
  validator.status(proposal.blck)

iterator committed*(validator: Validator): auto =
  var done = false
  var current = some validator.first
  while not done and round =? current:
    for member in validator.committee.ordered(round.number):
      let slot = round.slots[member]
      case slot.status
      of ProposalStatus.undecided:
        done = true
        break
      of ProposalStatus.skip, ProposalStatus.committed:
        discard
      of ProposalStatus.commit:
        slot.status = ProposalStatus.committed
        yield slot.proposal
    if not done:
      validator.remove(round)
      current = round.next
