import std/unittest
import pkg/questionable
import mysticeti
import ./examples
import ./mocks

suite "Validator":

  type Validator = mysticeti.Validator[MockSigning, MockHashing]

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

  test "validator includes blocks from previous round as parents":
    let proposal1 = validator.propose(seq[Transaction].example)
    let proposal2 = validator2.propose(seq[Transaction].example)
    let proposal3 = validator3.propose(seq[Transaction].example)
    validator.receive(proposal2)
    validator.receive(proposal3)
    validator.nextRound()
    let proposal4 = validator.propose(seq[Transaction].example)
    check proposal1.blck.blockHash in proposal4.blck.parents
    check proposal2.blck.blockHash in proposal4.blck.parents
    check proposal3.blck.blockHash in proposal4.blck.parents
