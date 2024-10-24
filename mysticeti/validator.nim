import ./basics
import ./signing
import ./committee
import ./blocks
import ./validator/slots
import ./validator/rounds

export slots

type Validator*[Signing, Hashing] = ref object
  identity: Identity[Signing]
  committee: Committee[Signing]
  membership: CommitteeMember
  rounds: Rounds[Hashing]

func new*(T: type Validator; identity: Identity, committee: Committee): ?!T =
  without membership =? committee.membership(identity.identifier):
    return T.failure "identity is not a member of the committee"
  success T(
    identity: identity,
    committee: committee,
    membership: membership,
    rounds: Rounds[T.Hashing].init(committee.size)
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
  validator.rounds.latest.addProposal(blck)
  validator.updateCertified(blck)
  validator.identity.sign(blck)

func receive*(validator: Validator, signed: SignedBlock): ?!void =
  without member =? validator.committee.membership(signed.signer):
    return failure "block is not signed by a committee member"
  if member != signed.blck.author:
    return failure "block is not signed by its author"
  for parent in signed.blck.parents:
    if parent.round >= signed.blck.round:
      return failure "block has a parent from an invalid round"
  for i in 0..<signed.blck.parents.len:
    for j in 0..<i:
      if signed.blck.parents[i] == signed.blck.parents[j]:
        return failure "block includes a parent more than once"
  validator.rounds.latest.addProposal(signed.blck)
  validator.updateSkipped(signed.blck)
  validator.updateCertified(signed.blck)
  success()

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
        discard
      todo.add(parentBlock.parents)
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
