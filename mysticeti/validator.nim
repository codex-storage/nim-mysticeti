import ./basics
import ./signing
import ./blocks

type
  Validator*[Signing, Hashing] = ref object
    identity: Identity[Signing]
    committee: Committee[Signing]
    round: Round[Signing, Hashing]
  Committee*[Signing] = ref object
    stakes: Table[Identifier[Signing], Stake]
  Stake = float64
  Round[Signing, Hashing] = ref object
    number: uint64
    previous: ?Round[Signing, Hashing]
    slots: Table[Identifier[Signing], ProposerSlot[Signing, Hashing]]
  ProposerSlot[Signing, Hashing] = object
    proposal: Block[Signing, Hashing]
    status: ProposalStatus
  ProposalStatus* = enum
    undecided
    toSkip
    toCommit

func new*(T: type Validator; identity: Identity, committee: Committee): T =
  let round = Round[T.Signing, T.Hashing](number: 0)
  T(identity: identity, committee: committee, round: round)

func new*(_: type Committee, stakes: openArray[(Identifier, Stake)]): auto =
  Committee[Identifier.Signing](stakes: stakes.toTable)

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
  validator.identity.sign(blck)

func receive*(validator: Validator, signed: SignedBlock) =
  validator.round.slots[signed.blck.author] = ProposerSlot.init(signed.blck)

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
