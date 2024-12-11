import ./basics
import mysticeti
import mysticeti/blocks

type Validator = mysticeti.Validator[MockDependencies]
type Committee = mysticeti.Committee[MockDependencies]
type Identity = MockIdentity
type Transaction = MockTransaction
type Block = MockBlock
type SignedBlock = blocks.SignedBlock[MockDependencies]

type NetworkSimulator* = object
  identities: seq[Identity]
  validators: seq[Validator]

proc init*(_: type NetworkSimulator, numberOfValidators = 4): NetworkSimulator =
  let identities = newSeqWith(numberOfValidators, Identity.init())
  let stakes = identities.mapIt( (it.identifier, 1/numberOfValidators) )
  let committee = Committee.new(stakes)
  let validators = identities.mapIt(Validator.new(it.identifier, committee))
  NetworkSimulator(identities: identities, validators: validators)

func identities*(simulator: NetworkSimulator): seq[Identity] =
  simulator.identities

func validators*(simulator: NetworkSimulator): seq[Validator] =
  simulator.validators

proc propose*(simulator: NetworkSimulator, validatorIndex: int): SignedBlock =
  let validator = simulator.validators[validatorIndex]
  let identity = simulator.identities[validatorIndex]
  let author = validator.membership
  let round = validator.round
  let parents = validator.parentBlocks()
  let transactions = seq[Transaction].example
  let blck = Block.new(author, round, parents, transactions)
  let signature = identity.sign(blck.id.hash)
  let signed = SignedBlock.init(blck, validator.identifier, signature)
  let checked = validator.check(signed)
  validator.add(checked.blck)
  signed

proc propose*(simulator: NetworkSimulator): seq[SignedBlock] =
  var proposals: seq[SignedBlock]
  for index in 0..<simulator.validators.len:
    proposals.add(simulator.propose(index))
  proposals

proc exchangeBlock*(proposer, receiver: Validator, blck: SignedBlock): ?!void =
  # check validity of block
  var checked = receiver.check(blck)
  # exchange missing parent blocks
  if checked.verdict == BlockVerdict.incomplete:
    for missing in checked.missing:
      if parent =? proposer.getBlock(missing):
        ? exchangeBlock(proposer, receiver, parent)
    checked = receiver.check(blck)
  # send proposal
  if checked.verdict == BlockVerdict.correct:
    receiver.add(checked.blck)
  success()

proc exchangeProposals*(simulator: NetworkSimulator, exchanges: openArray[(int, seq[int])]): ?!seq[SignedBlock] =
  # proposes new blocks and exchanges them with the specified receivers
  let proposals = exchanges.mapIt(simulator.propose(it[0]))
  for (index, exchange) in exchanges.pairs:
    let (proposer, receivers) = exchange
    let proposal = proposals[index]
    for receiver in receivers:
      if receiver != proposer:
        let proposingValidator = simulator.validators[proposer]
        let receivingValidator = simulator.validators[receiver]
        ? exchangeBlock(proposingValidator, receivingValidator, proposal)
  success proposals

proc exchangeProposals*(simulator: NetworkSimulator): ?!seq[SignedBlock] =
  # proposes and disseminates new blocks for all validators
  var exchanges: seq[(int, seq[int])]
  for proposer in simulator.validators.low..simulator.validators.high:
    let receivers = toSeq[simulator.validators.low..simulator.validators.high]
    exchanges.add( (proposer, receivers) )
  simulator.exchangeProposals(exchanges)
