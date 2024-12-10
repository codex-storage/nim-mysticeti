import mysticeti
import mysticeti/basics
import ./hashing
import ./transaction

type MockBlock* = ref object
  author*: CommitteeMember
  round*: uint64
  parents*: seq[BlockId[MockHash]]
  transactions*: seq[MockTransaction]
  id: ?BlockId[MockHash]

func new*(
  _: type MockBlock,
  author: CommitteeMember,
  round: uint64,
  parents: seq[BlockId[MockHash]],
  transactions: seq[MockTransaction]
): auto =
  MockBlock(
    author: author,
    round: round,
    parents: parents,
    transactions: transactions
  )

func id*(blck: MockBlock): auto =
  without var id =? blck.id:
    let blockBytes = cast[seq[byte]]($blck[])
    let blockHash = MockHash.hash(blockBytes)
    id = BlockId.init(blck.author, blck.round, blockHash)
    blck.id = some id
  id
