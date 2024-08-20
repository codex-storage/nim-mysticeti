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

type SignedBlock* = object
  blck: Block
  signatures: seq[Signature]

func blck*(signed: SignedBlock): Block =
  signed.blck

func toBytes(blck: Block): seq[byte] =
  discard # TODO

func sign*(identity: Identity, blck: Block): SignedBlock =
  let signature = identity.sign(blck.toBytes)
  SignedBlock(blck: blck, signatures: @[signature])

func sign*(identity: Identity, signed: SignedBlock): SignedBlock =
  let signature = identity.sign(signed.blck.toBytes)
  SignedBlock(blck: signed.blck, signatures: signed.signatures & signature)
