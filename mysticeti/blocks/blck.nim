import ../basics
import ../committee
import ./blockid

type
  Block*[Dependencies] = ref object
    author: CommitteeMember
    round: uint64
    parents: ImmutableSeq[BlockId[Dependencies]]
    transactions: ImmutableSeq[Dependencies.Transaction]
    id: ?BlockId[Dependencies]

func new*[Dependencies](
  _: type Block[Dependencies];
  author: CommitteeMember,
  round: uint64,
  parents: seq[BlockId[Dependencies]],
  transactions: seq[Dependencies.Transaction]
): auto =
  Block[Dependencies](
    author: author,
    round: round,
    parents: parents.immutable,
    transactions: transactions.immutable
  )

func author*(blck: Block): auto =
  blck.author

func round*(blck: Block): uint64 =
  blck.round

func parents*(blck: Block): auto =
  blck.parents

func transactions*(blck: Block): auto =
  blck.transactions

func id*(blck: Block): auto =
  without var id =? blck.id:
    type Dependencies = Block.Dependencies
    mixin hash
    let blockBytes = Dependencies.Serialization.toBytes(blck)
    let blockHash = Dependencies.Hash.hash(blockBytes)
    id = BlockId[Dependencies].new(blck.author, blck.round, blockHash)
    blck.id = some id
  id
