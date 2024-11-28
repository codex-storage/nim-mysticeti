import ../basics
import mysticeti

type Validator = mysticeti.Validator[MockDependencies]
type Identity = MockDependencies.Identity
type Committee = mysticeti.Committee[MockDependencies]
type Transaction = MockDependencies.Transaction

suite "Validator":

  var validator: Validator

  setup:
    let identity = Identity.init()
    let committee = Committee.new({identity.identifier: 1/1})
    validator = Validator.new(identity, committee)

  test "starts at round 0":
    check validator.round == 0

  test "can move to next round":
    validator.nextRound()
    check validator.round == 1
    validator.nextRound()
    validator.nextRound()
    check validator.round == 3

  test "validators sign their proposals":
    let proposal = !validator.propose(seq[Transaction].example)
    check proposal.blck.round == validator.round
    check proposal.blck.author == validator.membership
    check proposal.signer == validator.identifier

  test "validator cannot propose more than once in a round":
    discard !validator.propose(seq[Transaction].example)
    let outcome = validator.propose(seq[Transaction].example)
    check outcome.isFailure
    check outcome.error.msg == "already proposed this round"

  test "by default our own proposals are undecided":
    let proposal = !validator.propose(seq[Transaction].example)
    let round = proposal.blck.round
    let author = proposal.blck.author
    check validator.status(round, author) == some SlotStatus.undecided
