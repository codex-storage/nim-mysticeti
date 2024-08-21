import std/unittest
import pkg/questionable
import mysticeti
import ./examples
import ./mocks/signatures

suite "Validator":

  type Validator = mysticeti.Validator[MockSignatureScheme]

  var validator: Validator
  var validator2, validator3: Validator

  setup:
    validator = Validator.new()
    validator2 = Validator.new()
    validator3 = Validator.new()

  test "has a unique identifier":
    check Validator.new().identifier != Validator.new().identifier

  test "starts at round 0":
    check validator.round == 0

  test "can move to next round":
    validator.nextRound()
    check validator.round == 1
    validator.nextRound()
    validator.nextRound()
    check validator.round == 3

  test "validators sign their proposals":
    let proposal = validator.propose(seq[Transaction].example)
    check proposal.blck.author == validator.identifier
    check proposal.signer == validator.identifier

  test "validator cannot propose more than once in a round":
    discard validator.propose(seq[Transaction].example)
    expect AssertionDefect:
      discard validator.propose(seq[Transaction].example)

  test "by default our own proposals are undecided":
    let proposal = validator.propose(seq[Transaction].example)
    check validator.status(proposal) == some ProposalStatus.undecided

  test "by default received proposals are undecided":
    let proposal = validator2.propose(seq[Transaction].example)
    validator.receive(proposal)
    check validator.status(proposal) == some ProposalStatus.undecided
