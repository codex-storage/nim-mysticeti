import ../basics
import mysticeti
import mysticeti/blocks
import mysticeti/hashing

suite "Multiple Validators":

  type Validator = mysticeti.Validator[MockSigning, MockHashing]
  type Identity = mysticeti.Identity[MockSigning]
  type BlockId = blocks.BlockId[MockHashing]
  type Hash = hashing.Hash[MockHashing]

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
          !validator.receive(proposal)
    proposals

  test "validators include blocks from previous round as parents":
    let previous = exchangeProposals()
    nextRound()
    let proposal = validators[0].propose(seq[Transaction].example)
    for parent in previous:
      check parent.blck.id in proposal.blck.parents

  test "by default received proposals are undecided":
    let proposal = validators[1].propose(seq[Transaction].example)
    let round = proposal.blck.round
    let author = proposal.blck.author
    !validators[0].receive(proposal)
    check validators[0].status(round, author) == some SlotStatus.undecided

  test "refuses proposals that are not signed by the author":
    let proposal = validators[1].propose(seq[Transaction].example)
    let signedByOther = identities[2].sign(proposal.blck)
    let outcome = validators[0].receive(signedByOther)
    check outcome.isFailure
    check outcome.error.msg == "block is not signed by its author"

  test "refuses proposals that are not signed by a committee member":
    let otherIdentity = Identity.example
    let otherCommittee = Committee.new({otherIdentity.identifier: 1/1})
    let otherValidator = !Validator.new(otherIdentity, otherCommittee)
    let proposal = otherValidator.propose(seq[Transaction].example)
    let outcome = validators[0].receive(proposal)
    check outcome.isFailure
    check outcome.error.msg == "block is not signed by a committee member"

  test "refuses proposals that have a parent that is not from a previous round":
    let parents = exchangeProposals().mapIt(it.blck.id)
    let badParentRound = 1'u64
    let badParent = BlockId.new(CommitteeMember(0), badParentRound, Hash.example)
    nextRound()
    let blck = Block.new(
      CommitteeMember(0),
      round = 1,
      parents & badparent,
      seq[Transaction].example
    )
    let proposal = identities[0].sign(blck)
    let outcome = validators[1].receive(proposal)
    check outcome.isFailure
    check outcome.error.msg == "block has a parent from an invalid round"

  test "skips blocks that are ignored by >2f validators":
    # first round: other validators do not receive this proposal
    let proposal = validators[0].propose(seq[Transaction].example)
    let round = proposal.blck.round
    let author = proposal.blck.author
    # second round: voting
    nextRound()
    !validators[0].receive(validators[1].propose(seq[Transaction].example))
    !validators[0].receive(validators[2].propose(seq[Transaction].example))
    check validators[0].status(round, author) == some SlotStatus.undecided
    !validators[0].receive(validators[3].propose(seq[Transaction].example))
    check validators[0].status(round, author) == some SlotStatus.skip

  test "commits blocks that have >2f certificates":
    # first round: proposing
    let proposal = exchangeProposals()[0]
    let round = proposal.blck.round
    let author = proposal.blck.author
    # second round: voting
    nextRound()
    discard exchangeProposals()
    # third round: certifying
    nextRound()
    discard validators[0].propose(seq[Transaction].example)
    !validators[0].receive(validators[1].propose(seq[Transaction].example))
    check validators[0].status(round, author) == some SlotStatus.undecided
    !validators[0].receive(validators[2].propose(seq[Transaction].example))
    check validators[0].status(round, author) == some SlotStatus.commit

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

  test "commits blocks using the indirect decision rule":
    # first round: proposal is seen by majority
    let proposal = validators[0].propose(seq[Transaction].example)
    for index in 1..3:
      discard validators[index].propose(seq[Transaction].example)
    !validators[1].receive(proposal)
    !validators[2].receive(proposal)
    # second round: majority votes are only seen by first validator
    nextRound()
    discard validators[0].propose(seq[Transaction].example)
    let vote2 = validators[1].propose(seq[Transaction].example)
    let vote3 = validators[2].propose(seq[Transaction].example)
    discard validators[3].propose(seq[Transaction].example)
    !validators[0].receive(vote2)
    !validators[0].receive(vote3)
    # third round: only first validator creates a certificate
    nextRound()
    let certificate = validators[0].propose(seq[Transaction].example)
    for index in 1..3:
      discard validators[index].propose(seq[Transaction].example)
    !validators[1].receive(certificate)
    !validators[2].receive(certificate)
    !validators[3].receive(certificate)
    # fourth round: anchors
    nextRound()
    discard exchangeProposals()
    # fifth round: voting on anchors
    nextRound()
    discard exchangeProposals()
    # sixth round: certifying anchors
    nextRound()
    discard exchangeProposals()
    check toSeq(validators[0].committed()).?[0] == some proposal.blck
