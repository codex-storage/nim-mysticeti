import std/unittest
import pkg/questionable
import mysticeti
import ./examples
import ./mocks/identity

suite "Validator":

  var validator: Validator
  var validator2, validator3: Validator

  let scheme = mockIdentityScheme

  setup:
    validator = Validator.new(scheme)
    validator2 = Validator.new(scheme)
    validator3 = Validator.new(scheme)

  test "validators have a unique identifiers":
    check Validator.new(scheme).identifier != Validator.new(scheme).identifier

  test "starts at round 0":
    check validator.round == 0

  test "can move to next round":
    validator.nextRound()
    check validator.round == 1
    validator.nextRound()
    validator.nextRound()
    check validator.round == 3

  test "by default proposals are undecided":
    let proposal = validator.propose(seq[Transaction].example)
    check validator.status(proposal) == some ProposalStatus.undecided
