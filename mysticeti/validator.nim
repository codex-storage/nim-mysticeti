import ./basics
import ./committee
import ./blocks
import ./validator/slots
import ./validator/rounds
import ./validator/checks

export slots
export checks

type Validator*[Dependencies] = ref object
  identity: Identity[Dependencies]
  committee: Committee[Dependencies]
  membership: CommitteeMember
  rounds: Rounds[Dependencies]

func new*(T: type Validator; identity: Identity, committee: Committee): ?!T =
  without membership =? committee.membership(identity.identifier):
    return T.failure "identity is not a member of the committee"
  success T(
    identity: identity,
    committee: committee,
    membership: membership,
    rounds: Rounds[T.Dependencies].init(committee.size)
  )

func identifier*(validator: Validator): auto =
  validator.identity.identifier

func membership*(validator: Validator): CommitteeMember =
  validator.membership

func round*(validator: Validator): uint64 =
  validator.rounds.latest.number

func nextRound*(validator: Validator) =
  validator.rounds.addNewRound()

func skips(blck: Block, round: uint64, author: CommitteeMember): bool =
  for parent in blck.parents:
    if parent.round == round and parent.author == author:
      return false
  true

func updateSkipped(validator: Validator, supporter: Block) =
  if round =? validator.rounds.latest.find(supporter.round) and
     previous =? round.previous:
    for member in previous.members:
      let slot = previous[member]
      if supporter.skips(previous.number, member):
        let author = supporter.author
        let stake = validator.committee.stake(author)
        slot.skipBy(author, stake)

func updateCertified(validator: Validator, certificate: Block) =
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

func addBlock(validator: Validator, signedBlock: SignedBlock) =
  if round =? validator.rounds.latest.find(signedBlock.blck.round):
    round.addProposal(signedBlock)
    validator.updateSkipped(signedBlock.blck)
    validator.updateCertified(signedBlock.blck)

proc propose*(validator: Validator, transactions: seq[Transaction]): auto =
  type Block = blocks.Block[Validator.Dependencies]
  type SignedBlock = blocks.SignedBlock[Validator.Dependencies]
  let round = validator.rounds.latest
  if round[validator.membership].proposals.len > 0:
    return SignedBlock.failure "already proposed this round"
  var parents: seq[BlockId[Validator.Dependencies]]
  var parentStake: Stake
  if previous =? round.previous:
    for slot in previous.slots:
      if slot.proposals.len == 1:
        let parent = slot.proposals[0].blck
        parents.add(parent.id)
        parentStake += validator.committee.stake(parent.author)
  if round.number > 0:
    if parentStake <= 2/3:
      return SignedBlock.failure "not enough parents to represent > 2/3 stake"
  let blck = Block.new(
    author = validator.membership,
    round = round.number,
    parents = parents,
    transactions = transactions
  )
  let signedBlock = validator.identity.sign(blck)
  validator.addBlock(signedBlock)
  success signedBlock

func check*(validator: Validator, signed: SignedBlock): auto =
  type BlockCheck = checks.BlockCheck[SignedBlock.Dependencies]
  type BlockId = blocks.BlockId[SignedBlock.Dependencies]
  without member =? validator.committee.membership(signed.signer):
    return BlockCheck.invalid("block is not signed by a committee member")
  if member != signed.blck.author:
    return BlockCheck.invalid("block is not signed by its author")
  if signed.blck.round > validator.round:
    return BlockCheck.invalid("block has a round number that is too high")
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

func receive*(validator: Validator, correct: CorrectBlock) =
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
