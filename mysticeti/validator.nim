import ./basics
import ./signatures
import ./blocks

type
  Validator*[Scheme] = ref object
    identity: Identity[Scheme]
    round: Round[Scheme]
  Round[Scheme] = ref object
    number: uint64
    previous: ?Round[Scheme]
    proposals: Table[Identifier[Scheme], seq[Proposal[Scheme]]]
  Proposal[Scheme] = object
    blck: Block[Scheme]
    status: ProposalStatus
  ProposalStatus* = enum
    undecided
    toSkip
    toCommit

proc new*[Scheme](_: type Validator[Scheme]): Validator[Scheme] =
  Validator[Scheme](identity: Identity[Scheme].init(), round: Round[Scheme](number: 0))

func identifier*(validator: Validator): auto =
  validator.identity.identifier

func round*(validator: Validator): uint64 =
  validator.round.number

func nextRound*(validator: Validator) =
  let previous = validator.round
  validator.round = Round[Validator.Scheme](number: previous.number + 1, previous: some previous)

proc propose*(validator: Validator, transactions: seq[Transaction]): auto =
  assert validator.identifier notin validator.round.proposals
  var parents: seq[BlockHash]
  let blck = Block[Validator.Scheme].new(
    author = validator.identifier,
    round = validator.round.number,
    parents = parents,
    transactions = transactions
  )
  let proposal = Proposal[Validator.Scheme](blck: blck)
  validator.round.proposals[validator.identifier] = @[proposal]
  validator.identity.sign(blck)

func receive*(validator: Validator, signed: SignedBlock) =
  let proposal = Proposal[Validator.Scheme](blck: signed.blck)
  validator.round.proposals[signed.blck.author] = @[proposal]

func round(validator: Validator, number: uint64): auto =
  var round = validator.round
  while round.number > number and previous =? round.previous:
    round = previous
  if round.number == number:
    return some round

func status*(validator: Validator, blck: Block): ?ProposalStatus =
  if round =? round(validator, blck.round) and blck.author in round.proposals:
    let proposal = round.proposals[blck.author][0]
    some proposal.status
  else:
    none ProposalStatus

func status*(validator: Validator, proposal: SignedBlock): ?ProposalStatus =
  validator.status(proposal.blck)
