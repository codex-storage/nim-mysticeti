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

  proc exchangeProposals(exchanges: openArray[(int, seq[int])]): seq[SignedBlock] =
    for (proposer, receivers) in exchanges:
      let proposer = validators[proposer]
      let proposal = proposer.propose(seq[Transaction].example)
      for receiver in receivers:
        let receiver = validators[receiver]
        if receiver != proposer:
          !receiver.receive(proposal)
      result.add(proposal)

  proc exchangeProposals: seq[SignedBlock] =
    for proposer in validators:
      let proposal = proposer.propose(seq[Transaction].example)
      for receiver in validators:
        if receiver != proposer:
          !receiver.receive(proposal)
      result.add(proposal)

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
    let outcome = validators[1].receive(proposal)
    check outcome.isFailure
    check outcome.error.msg == "block includes a parent more than once"

  test "refuses proposals without >2/3 parents from the previous round":
    let parents = exchangeProposals().mapIt(it.blck.id)
    let blck = Block.new(
      CommitteeMember(0),
      round = 1,
      parents[0..<2],
      seq[Transaction].example
    )
    let proposal = identities[0].sign(blck)
    let outcome = validators[1].receive(proposal)
    check outcome.isFailure
    check outcome.error.msg ==
      "block does not include parents representing >2/3 stake from previous round"

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
    check toSeq(validators[0].committed()).contains(proposals[0].blck)
