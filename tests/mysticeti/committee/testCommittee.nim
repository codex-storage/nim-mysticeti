import ../basics
import mysticeti
import mysticeti/committee
import mysticeti/signing

suite "Committee":

  type Identifier = signing.Identifier[MockDependencies]
  type Committee = committee.Committee[MockDependencies]

  test "committee has numbered members":
    let identifiers = array[4, Identifier].example
    let stakes = identifiers.mapIt( (it, 1/4) )
    let committee = Committee.new(stakes)
    for (index, identifier) in identifiers.pairs:
      check committee.membership(identifier) == some CommitteeMember(index)

  test "members have stake":
    let identifiers = array[4, Identifier].example
    let stakes = @[
      (identifiers[0], 1/8),
      (identifiers[1], 1/2),
      (identifiers[2], 1/4),
      (identifiers[3], 1/8)
    ]
    let committee = Committee.new(stakes)
    for (identifier, stake) in stakes:
      let member = !committee.membership(identifier)
      check committee.stake(member) == stake

  test "no membership when identifier does not belong to a member":
    let identifiers = array[4, Identifier].example
    let stakes = identifiers.mapIt( (it, 1/4) )
    let committee = Committee.new(stakes)
    let other = Identifier.example
    check committee.membership(other) == none CommitteeMember

  test "stake of non-members is zero":
    let identifiers = array[4, Identifier].example
    let stakes = identifiers.mapIt( (it, 1/4) )
    let committee = Committee.new(stakes)
    let other = Identifier.example
    check committee.stake(other) == 0
