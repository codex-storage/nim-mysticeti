import std/unittest
import pkg/questionable
import mysticeti
import ./examples
import ./mocks

suite "Commitee of Validators":

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

  proc exchangeProposals: auto =
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
    (proposal1, proposal2, proposal3, proposal4)

  test "validators include blocks from previous round as parents":
    let previous = exchangeProposals()
    nextRound()
    let proposal = validator1.propose(seq[Transaction].example)
    check previous[0].blck.id in proposal.blck.parents
    check previous[1].blck.id in proposal.blck.parents
    check previous[2].blck.id in proposal.blck.parents
    check previous[3].blck.id in proposal.blck.parents

  test "by default received proposals are undecided":
    let proposal = validator2.propose(seq[Transaction].example)
    validator1.receive(proposal)
    check validator1.status(proposal) == some ProposalStatus.undecided

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
    let (proposal, _, _, _) = exchangeProposals()
    nextRound()
    discard exchangeProposals()
    nextRound()
    discard validator1.propose(seq[Transaction].example)
    validator1.receive(validator2.propose(seq[Transaction].example))
    check validator1.status(proposal) == some ProposalStatus.undecided
    validator1.receive(validator3.propose(seq[Transaction].example))
    check validator1.status(proposal) == some ProposalStatus.toCommit
