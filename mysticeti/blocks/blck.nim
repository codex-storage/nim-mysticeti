import ../basics
import ../committee
import ./blockid

type
  Block*[Dependencies] = object
    id: BlockId[Dependencies]
    author: CommitteeMember
    round: uint64
    parents: seq[BlockId[Dependencies]]
    transactions: seq[Transaction[Dependencies]]

func calculateId(blck: var Block) =
  type Dependencies = Block.Dependencies
  let bytes = Dependencies.Serialization.toBytes(blck)
  let hash = Hash[Dependencies].hash(bytes)
  blck.id = BlockId[Dependencies].new(blck.author, blck.round, hash)

func new*[Dependencies](
  _: type Block[Dependencies];
  author: CommitteeMember,
  round: uint64,
  parents: seq[BlockId[Dependencies]],
  transactions: seq[Transaction[Dependencies]]
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
