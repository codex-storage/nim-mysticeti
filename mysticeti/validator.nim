import ./basics
import ./identity
import ./blocks

type
  Validator* = ref object
    identity: Identity
    round: Round
  Round = ref object
    number: uint64
    previous: ?Round
    proposals: Table[Identifier, seq[Proposal]]
  Proposal = object
    blck: Block
    status: ProposalStatus
  ProposalStatus* = enum
    undecided
    toSkip
    toCommit

proc new*(_: type Validator, identities: IdentityScheme): Validator =
  Validator(identity: Identity.init(identities), round: Round(number: 0))

func identifier*(validator: Validator): Identifier =
  validator.identity.identifier

func nextRound*(validator: Validator) =
  let previous = validator.round
  validator.round = Round(number: previous.number + 1, previous: some previous)

func propose*(validator: Validator, transactions: seq[Transaction]): SignedBlock =
  var parents: seq[BlockHash]
  let blck = Block.new(
    author = validator.identifier,
    round = validator.round.number,
    parents = parents,
    transactions = transactions
  )
  let proposal = Proposal(blck: blck)
  validator.round.proposals[validator.identifier] = @[proposal]
  validator.identity.sign(blck)

func receive*(validator: Validator, proposal: SignedBlock) =
  discard

func round(validator: Validator, number: uint64): ?Round =
  var round = validator.round
  while round.number > number and previous =? round.previous:
    round = previous
  if round.number == number:
    some round
  else:
    none Round

func status*(validator: Validator, blck: Block): ?ProposalStatus =
  if round =? round(validator, blck.round) and blck.author in round.proposals:
    let proposal = round.proposals[blck.author][0]
    some proposal.status
  else:
    none ProposalStatus

func status*(validator: Validator, proposal: SignedBlock): ?ProposalStatus =
  validator.status(proposal.blck)
