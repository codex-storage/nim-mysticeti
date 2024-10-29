import ../basics
import mysticeti
import mysticeti/validator/slots

suite "Proposer Slots":

  type Block = mysticeti.Block[MockHashing]
  type BlockId = mysticeti.BlockId[MockHashing]
  type SignedBlock = mysticeti.SignedBlock[MockSigning, MockHashing]
  type Proposal = slots.Proposal[MockSigning, MockHashing]
  type ProposerSlot = slots.ProposerSlot[MockSigning, MockHashing]

  var slot: ProposerSlot

  setup:
    slot = ProposerSlot.new()

  test "slots are undecided by default":
    check slot.status == SlotStatus.undecided

  test "slots have no proposals initially":
    check slot.proposals.len == 0

  test "slots have not chosen a proposal initially":
    check slot.proposal == none Proposal

  test "blocks can be added to slots, and they become proposals":
    let blocks = seq[SignedBlock].example
    for blck in blocks:
      slot.addProposal(blck)
    for blck in blocks:
      check slot.proposals.anyIt(it.blck == blck.blck)

  test "proposals have no certificates initially":
    slot.addProposal(SignedBlock.example)
    let proposal = slot.proposals[0]
    check proposal.certificates.len == 0

  test "proposals can be certified by other blocks":
    slot.addProposal(SignedBlock.example)
    let proposal = slot.proposals[0]
    let certificate1, certificate2 = BlockId.example
    proposal.certifyBy(certificate1, Stake(1/9))
    proposal.certifyBy(certificate2, Stake(2/9))
    check proposal.certificates == @[certificate1, certificate2]

  test "slots can be committed when a proposal is certified by >2/3 stake":
    slot.addProposal(SignedBlock.example)
    let proposal = slot.proposals[0]
    proposal.certifyBy(BlockId.example, 1/3)
    check slot.status == SlotStatus.undecided
    proposal.certifyBy(BlockId.example, 1/3)
    check slot.status == SlotStatus.undecided
    proposal.certifyBy(BlockId.example, 1/1000)
    check slot.status == SlotStatus.commit

  test "slots choose a proposal when it is certified by >2/3 stake":
    slot.addProposal(SignedBlock.example)
    slot.addProposal(SignedBlock.example)
    let proposal = slot.proposals[1]
    proposal.certifyBy(BlockId.example, 1/3)
    check slot.proposal == none Proposal
    proposal.certifyBy(BlockId.example, 1/3)
    check slot.proposal == none Proposal
    proposal.certifyBy(BlockId.example, 1/1000)
    check slot.proposal == some proposal

  test "proposals can be certified by an anchor":
    let anchor = ProposerSlot.new()
    anchor.addProposal(SignedBlock.example)
    anchor.proposals[0].certifyBy(BlockId.example, 3/4)
    slot.addProposal(SignedBlock.example)
    let proposal = slot.proposals[0]
    proposal.certify(!anchor.proposal)
    check slot.status == SlotStatus.commit
    check slot.proposal == some proposal

  test "committing a slot marks it as committed and returns the chosen block":
    let block1, block2 = SignedBlock.example
    slot.addProposal(block1)
    slot.addProposal(block2)
    let proposal = slot.proposals[1]
    proposal.certifyBy(BlockId.example, 3/4)
    check slot.commit() == block2.blck
    check slot.status == SlotStatus.committed

  test "slots can be skipped when >2/3 stake skip it":
    slot.skipBy(1/3)
    check slot.status == SlotStatus.undecided
    slot.skipBy(1/3)
    check slot.status == SlotStatus.undecided
    slot.skipBy(1/1000)
    check slot.status == SlotStatus.skip

  test "slots can be skipped immediately":
    slot.skip()
    check slot.status == SlotStatus.skip
