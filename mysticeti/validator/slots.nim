import ../basics
import ../blocks
import ../committee

type
  ProposerSlot*[Hashing] = ref object
    proposals: seq[Proposal[Hashing]]
    skippedBy: Stake
    status: SlotStatus
  Proposal*[Hashing] = ref object
    slot: ProposerSlot[Hashing]
    blck: Block[Hashing]
    certifiedBy: Stake
    certificates: seq[BlockId[Hashing]]
  SlotStatus* {.pure.} = enum
    undecided
    skip
    commit
    committed

func proposals*(slot: ProposerSlot): auto =
  slot.proposals

func proposal*(slot: ProposerSlot): auto =
  if slot.proposals.len == 1:
    return some slot.proposals[0]
  if slot.status in [SlotStatus.commit, SlotStatus.committed]:
    for proposal in slot.proposals:
      if proposal.certifiedBy > 2/3:
        return some proposal

func status*(slot: ProposerSlot): auto =
  slot.status

func blck*(proposal: Proposal): auto =
  proposal.blck

func certificates*(proposal: Proposal): auto =
  proposal.certificates

func add*(slot: ProposerSlot, blck: Block) =
  let proposal = Proposal[Block.Hashing](slot: slot, blck: blck)
  slot.proposals.add(proposal)

func skipBy*(slot: ProposerSlot, stake: Stake) =
  slot.skippedBy += stake
  if slot.skippedBy > 2/3:
    slot.status = SlotStatus.skip

func skip*(slot: ProposerSlot) =
  assert slot.status == SlotStatus.undecided
  slot.status = SlotStatus.skip

func commit*(slot: ProposerSlot): auto =
  assert slot.status == SlotStatus.commit
  let proposal = !slot.proposal
  assert proposal.certifiedBy > 2/3
  slot.status = SlotStatus.committed
  return proposal.blck

func certifyBy*(proposal: Proposal, certificate: BlockId, stake: Stake) =
  proposal.certificates.add(certificate)
  proposal.certifiedBy += stake
  if proposal.certifiedBy > 2/3:
    proposal.slot.status = SlotStatus.commit

func certify*(proposal, anchor: Proposal) =
  assert proposal.slot.status == SlotStatus.undecided
  assert anchor.slot.status == SlotStatus.commit
  assert anchor.certifiedBy > 2/3
  proposal.certificates = @[anchor.blck.id]
  proposal.certifiedBy = anchor.certifiedBy
  proposal.slot.status = SlotStatus.commit
