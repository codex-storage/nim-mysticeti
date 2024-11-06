import ../basics
import ../committee
import ./blockid
import ./transaction

type
  Block*[Dependencies] = object
    author: CommitteeMember
    round: uint64
    parents: seq[BlockId[Dependencies]]
    transactions: seq[Transaction]

func new*[Dependencies](
  _: type Block[Dependencies];
  author: CommitteeMember,
  round: uint64,
  parents: seq[BlockId[Dependencies]],
  transactions: seq[Transaction]
): auto =
  Block[Dependencies](
    author: author,
    round: round,
    parents: parents,
    transactions: transactions
  )

func author*(blck: Block): auto =
  blck.author

func round*(blck: Block): uint64 =
  blck.round

func parents*(blck: Block): auto =
  blck.parents

func transactions*(blck: Block): auto =
  blck.transactions

func toBytes*(blck: Block): seq[byte] =
  cast[seq[byte]]($blck) # TODO: proper serialization

func id*(blck: Block): auto =
  BlockId[Block.Dependencies].new(
    blck.author,
    blck.round,
    Hash[Block.Dependencies].hash(blck.toBytes)
  )
