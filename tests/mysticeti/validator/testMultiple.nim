import ../basics
import mysticeti
import mysticeti/blocks
import mysticeti/hashing

suite "Multiple Validators":

  type Validator = mysticeti.Validator[MockSigning, MockHashing]
  type Identity = mysticeti.Identity[MockSigning]
  type BlockId = blocks.BlockId[MockHashing]
  type SignedBlock = blocks.SignedBlock[MockSigning, MockHashing]
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

  proc exchangeProposal(proposer, receiver: Validator, proposal: SignedBlock) =
    if receiver != proposer:
      var checked = receiver.check(proposal)
      if checked.verdict == BlockVerdict.incomplete:
        # exchange missing parent blocks
        for missing in checked.missing:
          let missingProposal = !proposer.getBlock(missing)
          exchangeProposal(proposer, receiver, missingProposal)
        checked = receiver.check(proposal)
      receiver.receive(checked.blck)

  proc exchangeProposals(exchanges: openArray[(int, seq[int])]): seq[SignedBlock] =
    for (proposer, receivers) in exchanges:
      let proposer = validators[proposer]
      let proposal = proposer.propose(seq[Transaction].example)
      for receiver in receivers:
        let receiver = validators[receiver]
        exchangeProposal(proposer, receiver, proposal)
      result.add(proposal)

  proc exchangeProposals: seq[SignedBlock] =
    var exchanges: seq[(int, seq[int])]
    for proposer in validators.low..validators.high:
      let receivers = toSeq[validators.low..validators.high]
      exchanges.add( (proposer, receivers) )
    exchangeProposals(exchanges)

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
    let checked = validators[0].check(proposal)
    validators[0].receive(checked.blck)
    check validators[0].status(round, author) == some SlotStatus.undecided

  test "refuses proposals that are not signed by the author":
    let proposal = validators[1].propose(seq[Transaction].example)
    let signedByOther = identities[2].sign(proposal.blck)
    let checked = validators[0].check(signedByOther)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block is not signed by its author"

  test "refuses proposals that are not signed by a committee member":
    let otherIdentity = Identity.example
    let otherCommittee = Committee.new({otherIdentity.identifier: 1/1})
    let otherValidator = !Validator.new(otherIdentity, otherCommittee)
    let proposal = otherValidator.propose(seq[Transaction].example)
    let checked = validators[0].check(proposal)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block is not signed by a committee member"

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
    let checked = validators[1].check(proposal)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block has a parent from an invalid round"

  test "refuses proposals that include a parent more than once":
    let parents = exchangeProposals().mapIt(it.blck.id)
    let badParent = parents.sample
    nextRound()
    let blck = Block.new(
      CommitteeMember(0),
      round = 1,
      parents & badparent,
      seq[Transaction].example
    )
    let proposal = identities[0].sign(blck)
    let checked = validators[1].check(proposal)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block includes a parent more than once"

  test "refuses proposals without >2/3 parents from the previous round":
    let parents = exchangeProposals().mapIt(it.blck.id)
    nextRound()
    let blck = Block.new(
      CommitteeMember(0),
      round = 1,
      parents[0..<2],
      seq[Transaction].example
    )
    let proposal = identities[0].sign(blck)
    let checked = validators[1].check(proposal)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason ==
      "block does not include parents representing >2/3 stake from previous round"

  test "refuses proposals with an unknown parent block":
    # first round: nobody recieves proposal from validator 0
    let parents = exchangeProposals {
      0: @[],
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3],
    }
    # second round: validator 0 creates block with parent that others didn't see
    nextRound()
    let proposal = validators[0].propose(seq[Transaction].example)
    # other validator will not accept block before it receives the parent
    let checked = validators[1].check(proposal)
    check checked.verdict == BlockVerdict.incomplete
    check checked.missing == @[parents[0].blck.id]

  test "does not refuse proposals with an unknown parent block that is too old":
    # first round: nobody receives proposal from validator 0
    discard exchangeProposals {
      0: @[],
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3]
    }
    # for the second to the sixth round, validator 0 is down
    for _ in 2..6:
      for validator in validators[1..3]:
        validator.nextRound()
      discard exchangeProposals {
        1: @[1, 2, 3],
        2: @[1, 2, 3],
        3: @[1, 2, 3]
      }
    # validator 1 cleans up old blocks
    discard toSeq(validators[1].committed())
    # validator 0 comes back online and creates block for second round
    validators[0].nextRound()
    let proposal = validators[0].propose(seq[Transaction].example)
    # validator 1 accepts block even though parent has already been cleaned up
    check validators[1].check(proposal).verdict == BlockVerdict.correct

  test "refuses proposals with a round number that is too high":
    discard exchangeProposals()
    validators[0].nextRound()
    let proposal = validators[0].propose(seq[Transaction].example)
    let checked = validators[1].check(proposal)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block has a round number that is too high"

  test "refuses a proposal that was already received":
    let proposals = exchangeProposals()
    let checked = validators[1].check(proposals[0])
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block already received"

  test "skips blocks that are ignored by >2f validators":
    # first round: other validators do not receive proposal from first validator
    let proposals = exchangeProposals {
      0: @[],
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3]
    }
    let round = proposals[0].blck.round
    let author = proposals[0].blck.author
    # second round: voting
    nextRound()
    let votes = validators.mapIt(it.propose(seq[Transaction].example))
    validators[0].receive(validators[0].check(votes[1]).blck)
    validators[0].receive(validators[0].check(votes[2]).blck)
    check validators[0].status(round, author) == some SlotStatus.undecided
    validators[0].receive(validators[0].check(votes[3]).blck)
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
    let certificates = validators.mapIt(it.propose(seq[Transaction].example))
    validators[0].receive(validators[0].check(certificates[1]).blck)
    check validators[0].status(round, author) == some SlotStatus.undecided
    validators[0].receive(validators[0].check(certificates[2]).blck)
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
    # first round: proposals
    let proposals = exchangeProposals {
      0: @[0, 1, 2, 3],
      1: @[0, 1],
      2: @[0, 2, 3],
      3: @[1, 2, 3]
    }
    # second round: voting
    nextRound()
    discard exchangeProposals {
      0: @[0, 1, 3],
      1: @[0, 1, 3],
      2: @[0, 3],
      3: @[1, 3]
    }
    # third round: certifying
    nextRound()
    discard exchangeProposals {
      0: @[0, 1, 2, 3],
      1: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3]
    }
    # fourth round: anchor
    nextRound()
    discard exchangeProposals()
    # fifth round: voting on anchor
    nextRound()
    discard exchangeProposals()
    # sixth round: certifying anchor
    nextRound()
    discard exchangeProposals()
    check toSeq(validators[0].committed()).contains(proposals[3].blck)
