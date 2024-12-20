import ../basics
import ../blocks
import ../committee

type
  ProposerSlot*[Dependencies] = ref object
    proposals: seq[Proposal[Dependencies]]
    skippedBy: Voting
    status: SlotStatus
  Proposal*[Dependencies] = ref object
    slot: ProposerSlot[Dependencies]
    signedBlock: SignedBlock[Dependencies]
    certifiedBy: Voting
    certificates: seq[typeof(Dependencies.Block.default.id)]
  SlotStatus* {.pure.} = enum
    undecided
    skip
    commit
    committed

func proposals*(slot: ProposerSlot): auto =
  slot.proposals

func proposal*(slot: ProposerSlot): auto =
  if slot.status in [SlotStatus.commit, SlotStatus.committed]:
    for proposal in slot.proposals:
      if proposal.certifiedBy.stake > 2/3:
        return some proposal

func status*(slot: ProposerSlot): auto =
  slot.status

func signedBlock*(proposal: Proposal): auto =
  proposal.signedBlock

func blck*(proposal: Proposal): auto =
  proposal.signedBlock.blck

func certificates*(proposal: Proposal): auto =
  proposal.certificates

func addProposal*(slot: ProposerSlot, signedBlock: SignedBlock) =
  let proposal = Proposal[ProposerSlot.Dependencies](
    slot: slot,
    signedBlock: signedBlock
  )
  slot.proposals.add(proposal)

func skipBy*(slot: ProposerSlot, member: CommitteeMember, stake: Stake) =
  slot.skippedBy.add(member, stake)
  if slot.skippedBy.stake > 2/3:
    slot.status = SlotStatus.skip

func skip*(slot: ProposerSlot) =
  assert slot.status == SlotStatus.undecided
  slot.status = SlotStatus.skip

func commit*(slot: ProposerSlot): auto =
  assert slot.status == SlotStatus.commit
  let proposal = !slot.proposal
  assert proposal.certifiedBy.stake > 2/3
  slot.status = SlotStatus.committed
  return proposal.blck

func certifyBy*(proposal: Proposal, certificate: BlockId, stake: Stake) =
  proposal.certificates.add(certificate)
  proposal.certifiedBy.add(certificate.author, stake)
  if proposal.certifiedBy.stake > 2/3:
    proposal.slot.status = SlotStatus.commit

func certify*(proposal, anchor: Proposal) =
  mixin id
  assert proposal.slot.status == SlotStatus.undecided
  assert anchor.slot.status == SlotStatus.commit
  assert anchor.certifiedBy.stake > 2/3
  proposal.certificates = @[anchor.blck.id]
  proposal.certifiedBy = anchor.certifiedBy
  proposal.slot.status = SlotStatus.commit
