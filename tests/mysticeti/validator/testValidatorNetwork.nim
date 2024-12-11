import ../basics
import ../simulator
import ../scenarios
import mysticeti
import mysticeti/blocks

suite "Validator Network":

  type Transaction = MockTransaction
  type Block = MockBlock
  type SignedBlock = blocks.SignedBlock[MockDependencies]
  type BlockId = blocks.BlockId[MockHash]
  type Hash = MockHash

  var simulator: NetworkSimulator

  setup:
    simulator = NetworkSimulator.init()

  test "validators starts at round 0":
    for validator in simulator.validators:
      check validator.round == 0

  test "validators move to the next round after receiving >2/3 stake proposals":
    let validator = simulator.validators[0]
    for round in 0'u64..10:
      check validator.round == round # 0/4 stake
      discard !simulator.exchangeProposals({0: @[0, 1, 2, 3]})
      check validator.round == round # 1/4 stake
      discard !simulator.exchangeProposals({1: @[0, 1, 2, 3]})
      check validator.round == round # 2/4 stake
      discard !simulator.exchangeProposals({2: @[0, 1, 2, 3]})
      check validator.round == round + 1 # 3/4 stake

  test "primary proposer rotates on a round-robin schedule":
    check simulator.validators.allIt(it.primaryProposer == CommitteeMember(0))
    discard !simulator.exchangeProposals()
    check simulator.validators.allIt(it.primaryProposer == CommitteeMember(1))
    discard !simulator.exchangeProposals()
    check simulator.validators.allIt(it.primaryProposer == CommitteeMember(2))
    discard !simulator.exchangeProposals()
    check simulator.validators.allIt(it.primaryProposer == CommitteeMember(3))
    discard !simulator.exchangeProposals()
    check simulator.validators.allIt(it.primaryProposer == CommitteeMember(0))

  test "validators expose blocks from previous round as parents":
    let previous = !simulator.exchangeProposals()
    let parents = simulator.validators[0].parentBlocks
    for proposal in previous:
      check proposal.blck.id in parents

  test "by default received proposals are undecided":
    let proposal = simulator.propose(1)
    let round = proposal.blck.round
    let author = proposal.blck.author
    let checked = simulator.validators[0].check(proposal)
    simulator.validators[0].add(checked.blck)
    check simulator.validators[0].status(round, author) == some SlotStatus.undecided

  test "refuses proposals that have an incorrect signature":
    let proposal = simulator.propose(1)
    let identifier = simulator.identities[1].identifier
    let wrongIdentity = simulator.identities[2]
    let wrongSignature = wrongIdentity.sign(proposal.blck.id.hash)
    let wrongSigned = SignedBlock.init(proposal.blck, identifier, wrongSignature)
    let checked = simulator.validators[0].check(wrongSigned)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block signature is incorrect"

  test "refuses proposals that are not signed by the author":
    let proposal = simulator.propose(1)
    let wrongIdentity = simulator.identities[2]
    let wrongIdentifier = wrongIdentity.identifier
    let wrongSignature = wrongIdentity.sign(proposal.blck.id.hash)
    let wrongSigned = SignedBlock.init(proposal.blck, wrongIdentifier, wrongSignature)
    let checked = simulator.validators[0].check(wrongSigned)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block is not signed by its author"

  test "refuses proposals that are not signed by a committee member":
    let otherSimulator = NetworkSimulator.init()
    let proposal = otherSimulator.propose(1)
    let checked = simulator.validators[0].check(proposal)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block is not signed by a committee member"

  test "refuses proposals that have a parent that is not from a previous round":
    let parents = (!simulator.exchangeProposals()).mapIt(it.blck.id)
    let badParentRound = 1'u64
    let badParent = BlockId.init(CommitteeMember(0), badParentRound, Hash.example)
    let blck = Block.new(
      CommitteeMember(0),
      round = 1,
      parents & badparent,
      seq[Transaction].example
    )
    let identity = simulator.identities[0]
    let signature = identity.sign(blck.id.hash)
    let proposal = SignedBlock.init(blck, identity.identifier, signature)
    let checked = simulator.validators[1].check(proposal)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block has a parent from an invalid round"

  test "refuses proposals that include a parent more than once":
    let parents = (!simulator.exchangeProposals()).mapIt(it.blck.id)
    let badParent = parents.sample
    let blck = Block.new(
      CommitteeMember(0),
      round = 1,
      parents & badparent,
      seq[Transaction].example
    )
    let identity = simulator.identities[0]
    let signature = identity.sign(blck.id.hash)
    let proposal = SignedBlock.init(blck, identity.identifier, signature)
    let checked = simulator.validators[1].check(proposal)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block includes a parent more than once"

  test "refuses proposals without >2/3 parents from the previous round":
    let parents = (!simulator.exchangeProposals()).mapIt(it.blck.id)
    let blck = Block.new(
      CommitteeMember(0),
      round = 1,
      parents[0..<2],
      seq[Transaction].example
    )
    let identity = simulator.identities[0]
    let signature = identity.sign(blck.id.hash)
    let proposal = SignedBlock.init(blck, identity.identifier, signature)
    let checked = simulator.validators[1].check(proposal)
    check checked.verdict == BlockVerdict.invalid
    check checked.reason ==
      "block does not include parents representing >2/3 stake from previous round"

  test "refuses proposals with an unknown parent block":
    # first round: nobody recieves proposal from validator 0
    let parents = !simulator.exchangeProposals {
      0: @[],
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3],
    }
    # second round: validator 0 creates block with parent that others didn't see
    let proposal = simulator.propose(0)
    # other validator will not accept block before it receives the parent
    let checked = simulator.validators[1].check(proposal)
    check checked.verdict == BlockVerdict.incomplete
    check checked.missing == @[parents[0].blck.id]

  test "does not refuse proposals with an unknown parent block that is too old":
    # first round: nobody receives proposal from validator 0
    discard !simulator.exchangeProposals {
      0: @[],
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3]
    }
    # for the second to the sixth round, validator 0 is down
    for _ in 2..6:
      discard !simulator.exchangeProposals {
        1: @[1, 2, 3],
        2: @[1, 2, 3],
        3: @[1, 2, 3]
      }
    # validator 1 cleans up old blocks
    discard toSeq(simulator.validators[1].committed())
    # validator 0 comes back online and creates block for second round
    let proposal = simulator.propose(0)
    # validator 1 accepts block even though parent has already been cleaned up
    let checked = simulator.validators[1].check(proposal)
    check checked.verdict == BlockVerdict.correct
    simulator.validators[1].add(checked.blck)

  test "refuses a proposal that was already received":
    let proposals = !simulator.exchangeProposals()
    let checked = simulator.validators[1].check(proposals[0])
    check checked.verdict == BlockVerdict.invalid
    check checked.reason == "block already received"

  test "skips blocks that are ignored by >2/3 stake":
    # first round: other validators do not receive proposal from first validator
    let proposals = !simulator.exchangeProposals {
      0: @[],
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3]
    }
    let round = proposals[0].blck.round
    let author = proposals[0].blck.author
    # second round: voting
    let votes = simulator.propose()
    simulator.validators[0].add(simulator.validators[0].check(votes[1]).blck)
    simulator.validators[0].add(simulator.validators[0].check(votes[2]).blck)
    check simulator.validators[0].status(round, author) == some SlotStatus.undecided
    simulator.validators[0].add(simulator.validators[0].check(votes[3]).blck)
    check simulator.validators[0].status(round, author) == some SlotStatus.skip

  test "skips blocks that are ignored by blocks that are received later":
    # first round: other validators do not receive proposal from first validator
    let proposals = !simulator.exchangeProposals {
      0: @[],
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3]
    }
    # second round: first validator does not receive votes
    discard !simulator.exchangeProposals {
      1: @[1, 2, 3],
      2: @[1, 2, 3],
      3: @[1, 2, 3]
    }
    # third round: first validator receives certificates, and also the votes
    # from the previous round because they are the parents of the certificates
    discard !simulator.exchangeProposals {
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3]
    }
    let round = proposals[0].blck.round
    let author = proposals[0].blck.author
    check simulator.validators[0].status(round, author) == some SlotStatus.skip

  test "commits blocks that have certificates representing >2/3 stake":
    # first round: proposing
    let proposal = !simulator.exchangeProposals()[0]
    let round = proposal.blck.round
    let author = proposal.blck.author
    # second round: voting
    discard !simulator.exchangeProposals()
    # third round: certifying
    let certificates = simulator.propose()
    simulator.validators[0].add(simulator.validators[0].check(certificates[1]).blck)
    check simulator.validators[0].status(round, author) == some SlotStatus.undecided
    simulator.validators[0].add(simulator.validators[0].check(certificates[2]).blck)
    check simulator.validators[0].status(round, author) == some SlotStatus.commit

  test "commits blocks that are certified by blocks that are received later":
    # first round: proposing
    let proposals = !simulator.exchangeProposals()
    # second round: first validator does not receive votes
    discard !simulator.exchangeProposals {
      1: @[1, 2, 3],
      2: @[1, 2, 3],
      3: @[1, 2, 3]
    }
    # third round: first validator does not receive certificates
    discard !simulator.exchangeProposals {
      1: @[1, 2, 3],
      2: @[1, 2, 3],
      3: @[1, 2, 3]
    }
    # fourth round: first validator receives votes and certificates, because
    # they are the parents of the blocks from this round
    discard !simulator.exchangeProposals {
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3]
    }
    let round = proposals[0].blck.round
    let author = proposals[0].blck.author
    check simulator.validators[0].status(round, author) == some SlotStatus.commit

  test "can iterate over the list of committed blocks":
    # blocks proposed in first round, in order of committee members
    let first = (!simulator.exchangeProposals()).mapIt(it.blck)
    # blocks proposed in second round, round-robin order
    let second = (!simulator.exchangeProposals()).mapIt(it.blck).rotatedLeft(1)
    # certify blocks from the first round
    discard !simulator.exchangeProposals()
    check toSeq(simulator.validators[0].committed()) == first
    # certify blocks from the second round
    discard !simulator.exchangeProposals()
    check toSeq(simulator.validators[0].committed()) == second

  test "commits blocks using the indirect decision rule":
    let proposals = !simulator.scenarioFigure4()
    let committed = toSeq(simulator.validators[0].committed())
    check committed.contains(proposals[0][3].blck)

  test "skips blocks using the indirect decision rule":
    let proposals = !simulator.scenarioFigure4()
    let committed = toSeq(simulator.validators[0].committed())
    check not committed.contains(proposals[0][1].blck)

  test "all validators emit blocks in the same sequence":
    let proposals = !simulator.scenarioFigure4()
    # commit sequence from appendix A of the Mysticeti paper:
    let expected = @[
        proposals[0][0].blck,
        proposals[0][2].blck,
        proposals[0][3].blck,
        proposals[1][1].blck
      ]
    for validator in simulator.validators:
      check toSeq(validator.committed()) == expected

  test "validators handle equivocation":
    # validator 0 creates two different proposals
    let proposalA, proposalB = simulator.propose(0)
    # validator 0 sends different proposals to different parts of the network
    !exchangeBlock(simulator.validators[0], simulator.validators[1], proposalA)
    !exchangeBlock(simulator.validators[0], simulator.validators[2], proposalA)
    !exchangeBlock(simulator.validators[0], simulator.validators[3], proposalB)
    #  other validators exchange proposals normally
    discard !simulator.exchangeProposals({
      1: @[0, 1, 2, 3],
      2: @[0, 1, 2, 3],
      3: @[0, 1, 2, 3]
    })
    # next rounds happen normally
    discard !simulator.exchangeProposals()
    discard !simulator.exchangeProposals()
    # check that only the proposal that was sent to the majority is committed
    for validator in simulator.validators:
      let sequence = toSeq(validator.committed())
      check proposalA.blck in sequence
      check proposalB.blck notin sequence
