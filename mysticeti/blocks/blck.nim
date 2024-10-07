import ../committee
import ../hashing
import ./blockid
import ./transaction

type
  Block*[Hashing] = object
    author: CommitteeMember
    round: uint64
    parents: seq[BlockId[Hashing]]
    transactions: seq[Transaction]

func new*(
  _: type Block,
  author: CommitteeMember,
  round: uint64,
  parents: seq[BlockId],
  transactions: seq[Transaction]
): auto =
  Block[BlockId.Hashing](
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
  BlockId.new(
    blck.author,
    blck.round,
    Block.Hashing.hash(blck.toBytes)
  )
