import ./basics
import ./signing
import ./committee
import ./blocks

type
  Validator*[Signing, Hashing] = ref object
    identity: Identity[Signing]
    committee: Committee[Signing]
    round: Round[Signing, Hashing]
  Round[Signing, Hashing] = ref object
    number: uint64
    previous: ?Round[Signing, Hashing]
    slots: Table[Identifier[Signing], ProposerSlot[Signing, Hashing]]
  ProposerSlot[Signing, Hashing] = object
    proposal: Block[Signing, Hashing]
    skippedBy: Stake
    certifiedBy: Stake
    status: ProposalStatus
  ProposalStatus* = enum
    undecided
    toSkip
    toCommit

func new*(T: type Validator; identity: Identity, committee: Committee): T =
  let round = Round[T.Signing, T.Hashing](number: 0)
  T(identity: identity, committee: committee, round: round)

func new*(_: type Round, number: uint64, previous: Round): auto =
  Round(number: number, previous: some previous)

func init(_: type ProposerSlot, proposal: Block): auto =
  ProposerSlot[Block.Signing, Block.Hashing](proposal: proposal)

func identifier*(validator: Validator): auto =
  validator.identity.identifier

func round*(validator: Validator): uint64 =
  validator.round.number

func nextRound*(validator: Validator) =
  let previous = validator.round
  validator.round = Round.new(previous.number + 1, previous)

func skips(blck: Block, round: uint64, author: Identifier): bool =
  for parent in blck.parents:
    if parent.round == round and parent.author == author:
      return false
  true

func updateSkipped(validator: Validator, received: Block) =
  if previous =? validator.round.previous:
    for (id, slot) in previous.slots.mpairs:
      if received.skips(previous.number, id):
        slot.skippedBy += validator.committee.stake(received.author)
      if slot.skippedBy > 2/3:
        slot.status = ProposalStatus.toSkip

func supports(blck: Block, round: uint64, author: Identifier): bool =
  for parent in blck.parents:
    if parent.round == round and parent.author == author:
      return true
  false

func updateCertified(validator: Validator, received: Block) =
  # three rounds: proposing -> supporting -> certifying
  let certifying = validator.round
  without supporting =? certifying.previous:
    return
  without proposing =? supporting.previous:
    return
  for (proposerId, proposerSlot) in proposing.slots.mpairs:
    var support: Stake
    for (supporterId, supporterSlot) in supporting.slots.pairs:
      if received.supports(supporting.number, supporterId):
        if supporterSlot.proposal.supports(proposing.number, proposerId):
          support += validator.committee.stake(supporterId)
    if support > 2/3:
      proposerSlot.certifiedBy += validator.committee.stake(received.author)
    if proposerSlot.certifiedBy > 2/3:
      proposerSlot.status = ProposalStatus.toCommit

proc propose*(validator: Validator, transactions: seq[Transaction]): auto =
  assert validator.identifier notin validator.round.slots
  var parents: seq[BlockId[Validator.Signing, Validator.Hashing]]
  if previous =? validator.round.previous:
    for id in previous.slots.keys:
      parents.add(previous.slots[id].proposal.id)
  let blck = Block.new(
    author = validator.identifier,
    round = validator.round.number,
    parents = parents,
    transactions = transactions
  )
  validator.round.slots[validator.identifier] = ProposerSlot.init(blck)
  validator.updateCertified(blck)
  validator.identity.sign(blck)

func receive*(validator: Validator, signed: SignedBlock) =
  validator.round.slots[signed.blck.author] = ProposerSlot.init(signed.blck)
  validator.updateSkipped(signed.blck)
  validator.updateCertified(signed.blck)

func round(validator: Validator, number: uint64): auto =
  var round = validator.round
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
