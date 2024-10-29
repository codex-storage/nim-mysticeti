import ./basics
import ./signing
import ./committee
import ./blocks
import ./validator/slots
import ./validator/rounds
import ./validator/checks

export slots
export checks

type Validator*[Signing, Hashing] = ref object
  identity: Identity[Signing]
  committee: Committee[Signing]
  membership: CommitteeMember
  rounds: Rounds[Signing, Hashing]

func new*(T: type Validator; identity: Identity, committee: Committee): ?!T =
  without membership =? committee.membership(identity.identifier):
    return T.failure "identity is not a member of the committee"
  success T(
    identity: identity,
    committee: committee,
    membership: membership,
    rounds: Rounds[T.Signing, T.Hashing].init(committee.size)
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
  if previous =? validator.rounds.latest.previous:
    for member in previous.members:
      let slot = previous[member]
      if supporter.skips(previous.number, member):
        let stake = validator.committee.stake(supporter.author)
        slot.skipBy(stake)

func updateCertified(validator: Validator, certificate: Block) =
  without (proposing, voting, _) =? validator.rounds.wave:
    return
  for proposal in proposing.proposals:
    var support: Stake
    for vote in voting.proposals:
      if proposal.blck.id in vote.blck.parents:
        if vote.blck.id in certificate.parents:
          support += validator.committee.stake(vote.blck.author)
    if support > 2/3:
      let stake = validator.committee.stake(certificate.author)
      proposal.certifyBy(certificate.id, stake)

proc propose*(validator: Validator, transactions: seq[Transaction]): auto =
  assert validator.rounds.latest[validator.membership].proposals.len == 0
  var parents: seq[BlockId[Validator.Hashing]]
  if previous =? validator.rounds.latest.previous:
    for slot in previous.slots:
      if slot.proposals.len == 1:
        parents.add(slot.proposals[0].blck.id)
  let blck = Block.new(
    author = validator.membership,
    round = validator.round,
    parents = parents,
    transactions = transactions
  )
  let signedBlock = validator.identity.sign(blck)
  validator.rounds.latest.addProposal(signedBlock)
  validator.updateCertified(blck)
  signedBlock

func check*(validator: Validator, signed: SignedBlock): auto =
  type BlockCheck = checks.BlockCheck[SignedBlock.Signing, SignedBlock.Hashing]
  type BlockId = blocks.BlockId[SignedBlock.Hashing]
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
    if validator.rounds.latest.find(parent).isNone:
      missing.add(parent)
  if missing.len > 0:
    return BlockCheck.incomplete(missing)
  BlockCheck.correct(signed)

func receive*(validator: Validator, correct: CorrectBlock) =
  if round =? validator.rounds.latest.find(correct.blck.round):
    round.addProposal(correct.signedBlock)
    validator.updateSkipped(correct.blck)
    validator.updateCertified(correct.blck)

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
