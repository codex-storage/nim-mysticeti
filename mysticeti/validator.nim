import ./basics
import ./signing
import ./hashing
import ./blocks

type
  Validator*[Signing, Hashing] = ref object
    identity: Identity[Signing]
    round: Round[Signing, Hashing]
  Round[Signing, Hashing] = ref object
    number: uint64
    previous: ?Round[Signing, Hashing]
    proposals: Table[Identifier[Signing], seq[Proposal[Signing, Hashing]]]
  Proposal[Signing, Hashing] = object
    blck: Block[Signing, Hashing]
    status: ProposalStatus
  ProposalStatus* = enum
    undecided
    toSkip
    toCommit

proc new*(T: type Validator): T =
  let identity = Identity[T.Signing].init()
  let round = Round[T.Signing, T.Hashing](number: 0)
  T(identity: identity, round: round)

func new*(_: type Round, number: uint64, previous: Round): auto =
  Round(number: number, previous: some previous)

func init*(_: type Proposal, blck: Block): auto =
  Proposal[Block.Signing, Block.Hashing](blck: blck)

func identifier*(validator: Validator): auto =
  validator.identity.identifier

func round*(validator: Validator): uint64 =
  validator.round.number

func nextRound*(validator: Validator) =
  let previous = validator.round
  validator.round = Round.new(previous.number + 1, previous)

proc propose*(validator: Validator, transactions: seq[Transaction]): auto =
  assert validator.identifier notin validator.round.proposals
  var parents: seq[Hash[Validator.Hashing]]
  if previous =? validator.round.previous:
    for id in previous.proposals.keys:
      parents.add(previous.proposals[id][0].blck.blockHash)
  let blck = Block.new(
    author = validator.identifier,
    round = validator.round.number,
    parents = parents,
    transactions = transactions
  )
  let proposal = Proposal.init(blck)
  validator.round.proposals[validator.identifier] = @[proposal]
  validator.identity.sign(blck)

func receive*(validator: Validator, signed: SignedBlock) =
  let proposal = Proposal.init(signed.blck)
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
