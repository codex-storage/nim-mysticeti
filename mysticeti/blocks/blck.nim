import ../basics
import ../committee
import ./blockid

type
  Block*[Dependencies] = object
    id: BlockId[Dependencies]
    author: CommitteeMember
    round: uint64
    parents: seq[BlockId[Dependencies]]
    transactions: seq[Dependencies.Transaction]

func calculateId(blck: var Block) =
  mixin hash
  type Dependencies = Block.Dependencies
  let blockBytes = Dependencies.Serialization.toBytes(blck)
  let blockHash = Dependencies.Hash.hash(blockBytes)
  blck.id = BlockId[Dependencies].new(blck.author, blck.round, blockHash)

func new*[Dependencies](
  _: type Block[Dependencies];
  author: CommitteeMember,
  round: uint64,
  parents: seq[BlockId[Dependencies]],
  transactions: seq[Dependencies.Transaction]
): auto =
  var blck = Block[Dependencies](
    author: author,
    round: round,
    parents: parents,
    transactions: transactions
  )
  blck.calculateId()
  blck

func author*(blck: Block): auto =
  blck.author

func round*(blck: Block): uint64 =
  blck.round

func parents*(blck: Block): auto =
  blck.parents

func transactions*(blck: Block): auto =
  blck.transactions

func id*(blck: Block): auto =
  blck.id
