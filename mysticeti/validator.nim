import ./basics
import ./committee
import ./blocks
import ./validator/slots
import ./validator/rounds
import ./validator/checks

export slots
export checks

type Validator*[Dependencies] = ref object
  identifier: Dependencies.Identifier
  committee: Committee[Dependencies.Identifier]
  membership: CommitteeMember
  rounds: Rounds[Dependencies]
  clockThreshold: Voting

func new*[Dependencies](
  _: type Validator[Dependencies],
  identifier: Dependencies.Identifier,
  committee: Committee[Dependencies.Identifier]
): Validator[Dependencies] =
  without membership =? committee.membership(identifier):
    raiseAssert "identity is not a member of the committee"
  Validator[Dependencies](
    identifier: identifier,
    committee: committee,
    membership: membership,
    rounds: Rounds[Dependencies].init(committee.size)
  )

func identifier*(validator: Validator): auto =
  validator.identifier

func membership*(validator: Validator): CommitteeMember =
  validator.membership

func round*(validator: Validator): uint64 =
  validator.rounds.latest.number

func primaryProposer*(validator: Validator): CommitteeMember =
  validator.rounds.latest.primaryProposer

func updateSkipped(validator: Validator, supporter: Validator.Dependencies.Block) =
  func skips(blck: Validator.Dependencies.Block, round: uint64, author: CommitteeMember): bool =
    for parent in blck.parents:
      if parent.round == round and parent.author == author:
        return false
    true
  if round =? validator.rounds.latest.find(supporter.round) and
     previous =? round.previous:
    for proposer in previous.proposers:
      let slot = previous[proposer]
      if supporter.skips(previous.number, proposer):
        let author = supporter.author
        let stake = validator.committee.stake(author)
        slot.skipBy(author, stake)

func updateCertified(validator: Validator, certificate: Validator.Dependencies.Block) =
  mixin id
  without certifying =? validator.rounds.latest.find(certificate.round) and
          voting =? certifying.previous and
          proposing =? voting.previous:
    return
  for proposal in proposing.proposals:
    var support: Voting
    for vote in voting.proposals:
      if proposal.blck.id in vote.blck.parents:
        if vote.blck.id in certificate.parents:
          let author = vote.blck.author
          let stake = validator.committee.stake(author)
          support.add(author, stake)
    if support.stake > 2/3:
      let stake = validator.committee.stake(certificate.author)
      proposal.certifyBy(certificate.id, stake)

func updateRound(validator: Validator, blck: Validator.Dependencies.Block) =
  if blck.round == validator.round:
    let author = blck.author
    let stake = validator.committee.stake(author)
    validator.clockThreshold.add(author, stake)
    if validator.clockThreshold.stake > 2/3:
      validator.rounds.addNewRound()
      validator.clockThreshold.reset()

func addBlock(validator: Validator, signedBlock: SignedBlock) =
  let blck = signedBlock.blck
  if round =? validator.rounds.latest.find(blck.round):
    round.addProposal(signedBlock)
    validator.updateSkipped(blck)
    validator.updateCertified(blck)
    validator.updateRound(blck)

func parentBlocks*(validator: Validator): auto =
  mixin id
  type Block = Validator.Dependencies.Block
  type BlockId = typeof(Block.default.id)
  var parents: seq[BlockId]
  if previous =? validator.rounds.latest.previous:
    for slot in previous.slots:
      if slot.proposals.len > 0:
        parents.add(slot.proposals[0].blck.id)
  parents

func check*(validator: Validator, signed: SignedBlock): auto =
  mixin id
  type BlockCheck = checks.BlockCheck[Validator.Dependencies]
  type Block = Validator.Dependencies.Block
  type BlockId = typeof(Block.default.id)
  if not signed.verifySignature():
    return BlockCheck.invalid("block signature is incorrect")
  without member =? validator.committee.membership(signed.signer):
    return BlockCheck.invalid("block is not signed by a committee member")
  if member != signed.blck.author:
    return BlockCheck.invalid("block is not signed by its author")
  for parent in signed.blck.parents:
    if parent.round >= signed.blck.round:
      return BlockCheck.invalid("block has a parent from an invalid round")
  for i in 0..<signed.blck.parents.len:
    for j in 0..<i:
      if signed.blck.parents[i] == signed.blck.parents[j]:
        return BlockCheck.invalid("block includes a parent more than once")
  if signed.blck.round > 0:
    var stake: Stake
    for parent in signed.blck.parents:
      if parent.round == signed.blck.round - 1:
        stake += validator.committee.stake(parent.author)
    if stake <= 2/3:
      return BlockCheck.invalid(
        "block does not include parents representing >2/3 stake from previous round"
      )
  var missing: seq[BlockId]
  for parent in signed.blck.parents:
    if parent.round >= validator.rounds.oldest.number:
      if validator.rounds.latest.find(parent).isNone:
        missing.add(parent)
  if missing.len > 0:
    return BlockCheck.incomplete(missing)
  if validator.rounds.latest.find(signed.blck.id).isSome:
    return BlockCheck.invalid("block already received")
  BlockCheck.correct(signed)

func add*(validator: Validator, correct: CorrectBlock) =
  validator.addBlock(correct.signedBlock)

func getBlock*(validator: Validator, id: BlockId): auto =
  validator.rounds.latest.find(id)

func status*(validator: Validator, round: uint64, author: CommitteeMember): auto =
  if round =? validator.rounds.oldest.find(round):
    return some round[author].status

func updateIndirect(validator: Validator, slot: ProposerSlot, round: Round) =
  without anchor =? round.findAnchor():
    return
  without anchorProposal =? anchor.proposal:
    return
  var todo = anchorProposal.blck.parents
  while todo.len > 0:
    let parent = todo.pop()
    if parent.round < round.number + 2:
      continue
    for slotProposal in slot.proposals:
      if parent in slotProposal.certificates:
        slotProposal.certify(anchorProposal)
        return
      without parentBlock =? round.find(parent):
        raiseAssert "parent block not found"
      todo.add(parentBlock.blck.parents)
  slot.skip()

iterator committed*(validator: Validator): auto =
  var done = false
  while not done:
    let round = validator.rounds.oldest
    for slot in round.slots:
      if slot.status == SlotStatus.undecided:
        validator.updateIndirect(slot, round)
      case slot.status
      of SlotStatus.undecided:
        done = true
        break
      of SlotStatus.skip, SlotStatus.committed:
        discard
      of SlotStatus.commit:
        yield slot.commit()
    if not done:
      validator.rounds.removeOldestRound()
