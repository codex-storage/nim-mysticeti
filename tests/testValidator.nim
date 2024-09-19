import std/unittest
import pkg/questionable
import mysticeti
import ./examples
import ./mocks

suite "Validator":

  type Validator = mysticeti.Validator[MockSigning, MockHashing]
  type Identity = mysticeti.Identity[MockSigning]

  var validator1, validator2, validator3, validator4: Validator

  setup:
    let identity1, identity2, identity3, identity4 = Identity.init()
    let committee = Committee.new({
      identity1.identifier: 1/4,
      identity2.identifier: 1/4,
      identity3.identifier: 1/4,
      identity4.identifier: 1/4
    })
    validator1 = Validator.new(identity1, committee)
    validator2 = Validator.new(identity2, committee)
    validator3 = Validator.new(identity3, committee)
    validator4 = Validator.new(identity4, committee)

  proc nextRound =
    validator1.nextRound()
    validator2.nextRound()
    validator3.nextRound()
    validator4.nextRound()

  test "starts at round 0":
    check validator1.round == 0

  test "can move to next round":
    validator1.nextRound()
    check validator1.round == 1
    validator1.nextRound()
    validator1.nextRound()
    check validator1.round == 3

  test "validators sign their proposals":
    let proposal = validator1.propose(seq[Transaction].example)
    check proposal.blck.author == validator1.identifier
    check proposal.signer == validator1.identifier

  test "validator cannot propose more than once in a round":
    discard validator1.propose(seq[Transaction].example)
    expect AssertionDefect:
      discard validator1.propose(seq[Transaction].example)

  test "by default our own proposals are undecided":
    let proposal = validator1.propose(seq[Transaction].example)
    check validator1.status(proposal) == some ProposalStatus.undecided

  test "by default received proposals are undecided":
    let proposal = validator2.propose(seq[Transaction].example)
    validator1.receive(proposal)
    check validator1.status(proposal) == some ProposalStatus.undecided

  test "validator includes blocks from previous round as parents":
    let proposal1 = validator1.propose(seq[Transaction].example)
    let proposal2 = validator2.propose(seq[Transaction].example)
    let proposal3 = validator3.propose(seq[Transaction].example)
    let proposal4 = validator4.propose(seq[Transaction].example)
    validator1.receive(proposal2)
    validator1.receive(proposal3)
    validator1.receive(proposal4)
    validator1.nextRound()
    let proposal5 = validator1.propose(seq[Transaction].example)
    check proposal1.blck.id in proposal5.blck.parents
    check proposal2.blck.id in proposal5.blck.parents
    check proposal3.blck.id in proposal5.blck.parents
    check proposal4.blck.id in proposal5.blck.parents

  test "skips blocks that are ignored by >2f validators":
    # other validators do not receive this proposal:
    let proposal = validator1.propose(seq[Transaction].example)
    nextRound()
    validator1.receive(validator2.propose(seq[Transaction].example))
    validator1.receive(validator3.propose(seq[Transaction].example))
    check validator1.status(proposal) == some ProposalStatus.undecided
    validator1.receive(validator4.propose(seq[Transaction].example))
    check validator1.status(proposal) == some ProposalStatus.toSkip
  test "commits blocks that have >2f certificates":
    let proposal1 = validator1.propose(seq[Transaction].example)
    let proposal2 = validator2.propose(seq[Transaction].example)
    let proposal3 = validator3.propose(seq[Transaction].example)
    let proposal4 = validator4.propose(seq[Transaction].example)
    validator1.receive(proposal2)
    validator1.receive(proposal3)
    validator1.receive(proposal4)
    validator2.receive(proposal1)
    validator2.receive(proposal3)
    validator2.receive(proposal4)
    validator3.receive(proposal1)
    validator3.receive(proposal2)
    validator3.receive(proposal4)
    validator4.receive(proposal1)
    validator4.receive(proposal2)
    validator4.receive(proposal3)
    nextRound()
    let proposal5 = validator1.propose(seq[Transaction].example)
    let proposal6 = validator2.propose(seq[Transaction].example)
    let proposal7 = validator3.propose(seq[Transaction].example)
    let proposal8 = validator4.propose(seq[Transaction].example)
    validator1.receive(proposal6)
    validator1.receive(proposal7)
    validator1.receive(proposal8)
    validator2.receive(proposal5)
    validator2.receive(proposal7)
    validator2.receive(proposal8)
    validator3.receive(proposal5)
    validator3.receive(proposal6)
    validator3.receive(proposal8)
    validator4.receive(proposal5)
    validator4.receive(proposal6)
    validator4.receive(proposal7)
    nextRound()
    discard validator1.propose(seq[Transaction].example)
    let proposal10 = validator2.propose(seq[Transaction].example)
    let proposal11 = validator3.propose(seq[Transaction].example)
    validator1.receive(proposal10)
    check validator1.status(proposal1) == some ProposalStatus.undecided
    validator1.receive(proposal11)
    check validator1.status(proposal1) == some ProposalStatus.toCommit
