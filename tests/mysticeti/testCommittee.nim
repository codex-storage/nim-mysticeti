import std/unittest
import std/sequtils
import std/algorithm
import pkg/questionable
import pkg/questionable/results
import mysticeti
import ./examples
import ./mocks

suite "Commitee of Validators":

  type Validator = mysticeti.Validator[MockSigning, MockHashing]
  type Identity = mysticeti.Identity[MockSigning]

  var validators: seq[Validator]

  setup:
    let identities = newSeqWith(4, Identity.init())
    let stakes = identities.mapIt( (it.identifier, 1/4) )
    let committee = Committee.new(stakes)
    validators = identities.mapIt(!Validator.new(it, committee))

  proc nextRound =
    for validator in validators:
      validator.nextRound()

  proc exchangeProposals: auto =
    let proposals = validators.mapIt(it.propose(seq[Transaction].example))
    for validator in validators:
      for proposal in proposals:
        if proposal.blck.author != validator.membership:
          validator.receive(proposal)
    proposals

  test "validators include blocks from previous round as parents":
    let previous = exchangeProposals()
    nextRound()
    let proposal = validators[0].propose(seq[Transaction].example)
    for parent in previous:
      check parent.blck.id in proposal.blck.parents

  test "by default received proposals are undecided":
    let proposal = validators[1].propose(seq[Transaction].example)
    validators[0].receive(proposal)
    check validators[0].status(proposal) == some ProposalStatus.undecided

  test "skips blocks that are ignored by >2f validators":
    # first round: other validators do not receive this proposal
    let proposal = validators[0].propose(seq[Transaction].example)
    # second round: voting
    nextRound()
    validators[0].receive(validators[1].propose(seq[Transaction].example))
    validators[0].receive(validators[2].propose(seq[Transaction].example))
    check validators[0].status(proposal) == some ProposalStatus.undecided
    validators[0].receive(validators[3].propose(seq[Transaction].example))
    check validators[0].status(proposal) == some ProposalStatus.skip

  test "commits blocks that have >2f certificates":
    # first round: proposing
    let proposals = exchangeProposals()
    # second round: voting
    nextRound()
    discard exchangeProposals()
    # third round: certifying
    nextRound()
    discard validators[0].propose(seq[Transaction].example)
    validators[0].receive(validators[1].propose(seq[Transaction].example))
    check validators[0].status(proposals[0]) == some ProposalStatus.undecided
    validators[0].receive(validators[2].propose(seq[Transaction].example))
    check validators[0].status(proposals[0]) == some ProposalStatus.commit

  test "can iterate over the list of committed blocks":
    # blocks proposed in first round, in order of committee members
    let first = exchangeProposals().mapIt(it.blck)
    nextRound()
    # blocks proposed in second round, round-robin order
    let second = exchangeProposals().mapIt(it.blck).rotatedLeft(1)
    nextRound()
    # certify blocks from the first round
    discard exchangeProposals()
    check toSeq(validators[0].committed()) == first
    # certify blocks from the second round
    nextRound()
    discard exchangeProposals()
    check toSeq(validators[0].committed()) == second

