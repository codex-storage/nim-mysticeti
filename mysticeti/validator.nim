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

func identifier*[Scheme](validator: Validator[Scheme]): Identifier[Scheme] =
  validator.identity.identifier

func round*[Scheme](validator: Validator[Scheme]): uint64 =
  validator.round.number

func nextRound*[Scheme](validator: Validator[Scheme]) =
  let previous = validator.round
  validator.round = Round[Scheme](number: previous.number + 1, previous: some previous)

proc propose*[Scheme](validator: Validator[Scheme], transactions: seq[Transaction]): SignedBlock[Scheme] =
  assert validator.identifier notin validator.round.proposals
  var parents: seq[BlockHash]
  let blck = Block[Scheme].new(
    author = validator.identifier,
    round = validator.round.number,
    parents = parents,
    transactions = transactions
  )
  let proposal = Proposal[Scheme](blck: blck)
  validator.round.proposals[validator.identifier] = @[proposal]
  validator.identity.sign(blck)

func receive*[Scheme](validator: Validator[Scheme], signed: SignedBlock[Scheme]) =
  let proposal = Proposal[Scheme](blck: signed.blck)
  validator.round.proposals[signed.blck.author] = @[proposal]

func round[Scheme](validator: Validator[Scheme], number: uint64): ?Round[Scheme] =
  var round = validator.round
  while round.number > number and previous =? round.previous:
    round = previous
  if round.number == number:
    some round
  else:
    none Round[Scheme]

func status*[Scheme](validator: Validator[Scheme], blck: Block[Scheme]): ?ProposalStatus =
  if round =? round(validator, blck.round) and blck.author in round.proposals:
    let proposal = round.proposals[blck.author][0]
    some proposal.status
  else:
    none ProposalStatus

func status*[Scheme](validator: Validator[Scheme], proposal: SignedBlock[Scheme]): ?ProposalStatus =
  validator.status(proposal.blck)
