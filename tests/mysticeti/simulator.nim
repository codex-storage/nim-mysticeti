import ./basics
import mysticeti
import mysticeti/blocks

type Validator = mysticeti.Validator[MockSigning, MockHashing]
type Identity = mysticeti.Identity[MockSigning]
type SignedBlock = blocks.SignedBlock[MockSigning, MockHashing]

type NetworkSimulator* = object
  identities: seq[Identity]
  validators: seq[Validator]

proc init*(_: type NetworkSimulator, numberOfValidators = 4): NetworkSimulator =
  let identities = newSeqWith(numberOfValidators, Identity.init())
  let stakes = identities.mapIt( (it.identifier, 1/numberOfValidators) )
  let committee = Committee.new(stakes)
  let validators = identities.mapIt(!Validator.new(it, committee))
  NetworkSimulator(identities: identities, validators: validators)

func identities*(simulator: NetworkSimulator): seq[Identity] =
  simulator.identities

func validators*(simulator: NetworkSimulator): seq[Validator] =
  simulator.validators

func nextRound*(simulator: NetworkSimulator) =
  for validator in simulator.validators:
    validator.nextRound()

proc propose*(simulator: NetworkSimulator, validatorIndex: int): ?!SignedBlock =
  simulator.validators[validatorIndex].propose(seq[Transaction].example)

proc propose*(simulator: NetworkSimulator): ?!seq[SignedBlock] =
  success simulator.validators.mapit(? it.propose(seq[Transaction].example))
