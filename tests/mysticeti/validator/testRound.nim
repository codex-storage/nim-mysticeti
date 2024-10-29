import ../basics
import mysticeti
import mysticeti/blocks
import mysticeti/validator/slots
import mysticeti/validator/round

suite "Validator Round":

  type Round = round.Round[MockSigning, MockHashing]
  type Block = mysticeti.Block[MockHashing]
  type SignedBlock = mysticeti.SignedBlock[MockSigning, MockHashing]

  test "rounds have a number":
    check Round.new(0, 1).number == 0
    check Round.new(42, 1).number == 42
    check Round.new(1337, 1).number == 1337

  test "round has a fixed number of slots":
    check toSeq(Round.new(0, 1).slots).len == 1
    check toSeq(Round.new(0, 42).slots).len == 42
    check toSeq(Round.new(0, 1337).slots).len == 1337

  test "round requires at least one slot":
    expect Defect:
      discard Round.new(0, 0)

  test "round has a slot for each committee member":
    let round = Round.new(0, 4)
    check not isNil round[CommitteeMember(0)]
    check not isNil round[CommitteeMember(1)]
    check not isNil round[CommitteeMember(2)]
    check not isNil round[CommitteeMember(3)]
    expect Defect:
      discard round[CommitteeMember(4)]

  test "round stores proposed blocks in the corresponding slots":
    let round = Round.new(0, 4)
    let block1 = SignedBlock.example(author = CommitteeMember(1), round = 0)
    let block2 = SignedBlock.example(author = CommitteeMember(2), round = 0)
    let block3 = SignedBlock.example(author = CommitteeMember(2), round = 0)
    round.addProposal(block1)
    round.addProposal(block2)
    round.addProposal(block3)
    let slot1 = round[CommitteeMember(1)]
    check slot1.proposals.len == 1
    check slot1.proposals[0].blck == block1.blck
    let slot2 = round[CommitteeMember(2)]
    check slot2.proposals.len == 2
    check slot2.proposals[0].blck == block2.blck
    check slot2.proposals[1].blck == block3.blck

  test "round does not accept blocks meant for different rounds":
    let blck = SignedBlock.example(author = CommitteeMember(0), round = 42)
    let round42 = Round.new(42, 4)
    let round43 = Round.new(43, 4)
    round42.addProposal(blck)
    expect Defect:
      round43.addProposal(blck)

  test "round is part of a doubly linked list":
    let first = Round.new(0, 4)
    let second = Round.new(first)
    let third = Round.new(second)
    check first.previous == none Round
    check first.next == some second
    check second.previous == some first
    check second.next == some third
    check third.previous == some second
    check third.next == none Round

  test "doubly linked list has increasing round numbers":
    let first = Round.new(42, 4)
    let second = Round.new(first)
    let third = Round.new(second)
    check first.number == 42
    check second.number == 43
    check third.number == 44

  test "doubly linked list can be used to find a round by its number":
    let first = Round.new(42, 4)
    let second = Round.new(first)
    let third = Round.new(second)
    for round in [first, second, third]:
      check round.find(41'u64) == none Round
      check round.find(42'u64) == some first
      check round.find(43'u64) == some second
      check round.find(44'u64) == some third
      check round.find(45'u64) == none Round

  test "doubly linked list can be used to find a block":
    let first = Round.new(42, 4)
    let second = Round.new(first)
    let third = Round.new(second)
    let block1 = SignedBlock.example(author = CommitteeMember(1), round = 42)
    let block2 = SignedBlock.example(author = CommitteeMember(2), round = 43)
    let block3 = SignedBlock.example(author = CommitteeMember(2), round = 43)
    first.addProposal(block1)
    second.addProposal(block2)
    second.addProposal(block3)
    for round in [first, second, third]:
      check round.find(block1.blck.id) == some block1
      check round.find(block2.blck.id) == some block2
      check round.find(block3.blck.id) == some block3
      check round.find(Block.example.id) == none SignedBlock

  test "round can be removed from a doubly linked list":
    let first = Round.new(42, 4)
    let second = Round.new(first)
    let third = Round.new(second)
    second.remove()
    check first.previous == none Round
    check first.next == some third
    check second.previous == none Round
    check second.next == none Round
    check third.previous == some first
    check third.next == none Round
    third.remove()
    check first.previous == none Round
    check first.next == none Round
    check third.previous == none Round
    check third.next == none Round

  test "members are ordered round-robin for each round":
    var round: Round
    round = Round.new(0, 4)
    check toSeq(round.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))
    round = Round.new(1, 4)
    check toSeq(round.members) == @[1, 2, 3, 0].mapIt(CommitteeMember(it))
    round = Round.new(2, 4)
    check toSeq(round.members) == @[2, 3, 0, 1].mapIt(CommitteeMember(it))
    round = Round.new(3, 4)
    check toSeq(round.members) == @[3, 0, 1, 2].mapIt(CommitteeMember(it))
    round = Round.new(4, 4)
    check toSeq(round.members) == @[0, 1, 2, 3].mapIt(CommitteeMember(it))

  test "slots are ordered round-robin too":
    let round = Round.new(2, 4)
    let slots = toSeq(round.slots)
    check slots[0] == round[CommitteeMember(2)]
    check slots[1] == round[CommitteeMember(3)]
    check slots[2] == round[CommitteeMember(0)]
    check slots[3] == round[CommitteeMember(1)]

  test "proposals are ordered round-robin as well":
    var blocks: seq[SignedBlock]
    blocks.add(SignedBlock.example(author = CommitteeMember(0), round = 2))
    blocks.add(SignedBlock.example(author = CommitteeMember(0), round = 2))
    blocks.add(SignedBlock.example(author = CommitteeMember(1), round = 2))
    blocks.add(SignedBlock.example(author = CommitteeMember(1), round = 2))
    blocks.add(SignedBlock.example(author = CommitteeMember(2), round = 2))
    blocks.add(SignedBlock.example(author = CommitteeMember(2), round = 2))
    blocks.add(SignedBlock.example(author = CommitteeMember(3), round = 2))
    blocks.add(SignedBlock.example(author = CommitteeMember(3), round = 2))
    let round = Round.new(2, 4)
    for blck in blocks:
      round.addProposal(blck)
    let proposals = toSeq(round.proposals)
    check proposals[0].blck == blocks[4].blck
    check proposals[1].blck == blocks[5].blck
    check proposals[2].blck == blocks[6].blck
    check proposals[3].blck == blocks[7].blck
    check proposals[4].blck == blocks[0].blck
    check proposals[5].blck == blocks[1].blck
    check proposals[6].blck == blocks[2].blck
    check proposals[7].blck == blocks[3].blck

  test "doubly linked list can be used to find the anchor for a round":
    let proposing = Round.new(2, 4)
    let voting = Round.new(proposing)
    let certifying = Round.new(voting)
    let anchoring = Round.new(certifying)
    let orderedSlots = toSeq(anchoring.slots)
    check proposing.findAnchor() == some orderedSlots[0]
    orderedSlots[0].skip()
    check proposing.findAnchor() == some orderedSlots[1]
    orderedSlots[1].skip()
    check proposing.findAnchor() == some orderedSlots[2]
