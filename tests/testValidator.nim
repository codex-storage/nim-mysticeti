import std/unittest
import pkg/questionable
import mysticeti
import ./examples

suite "Validator":

  var validator: Validator
  var validator2, validator3: Validator

  setup:
    validator = Validator.new()
    validator2 = Validator.new()
    validator3 = Validator.new()

  test "by default proposals are undecided":
    let proposal = validator.propose(seq[Transaction].example)
    check validator.status(proposal) == some ProposalStatus.undecided
