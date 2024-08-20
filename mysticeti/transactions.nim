import ./identity

type Transaction* = object

type
  Block* = object
    author: Identifier
    round: uint64
    parents: seq[BlockHash]
    transactions: seq[Transaction]
  BlockHash* = object

func new*(
  _: type Block,
  author: Identifier,
  round: uint64,
  parents: seq[BlockHash],
  transactions: seq[Transaction]
): Block =
  Block(
    author: author,
    round: round,
    parents: parents,
    transactions: transactions
  )

func author*(blck: Block): Identifier =
  blck.author

func round*(blck: Block): uint64 =
  blck.round
