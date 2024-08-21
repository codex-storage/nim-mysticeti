import ./signatures

type Transaction* = object

type
  Block*[Scheme] = object
    author: Identifier[Scheme]
    round: uint64
    parents: seq[BlockHash]
    transactions: seq[Transaction]
  BlockHash* = object

func new*[Scheme](
  _: type Block[Scheme],
  author: Identifier,
  round: uint64,
  parents: seq[BlockHash],
  transactions: seq[Transaction]
): Block[Scheme] =
  Block[Scheme](
    author: author,
    round: round,
    parents: parents,
    transactions: transactions
  )

func author*(blck: Block): auto =
  blck.author

func round*(blck: Block): uint64 =
  blck.round


type SignedBlock*[Scheme] = object
  blck: Block[Scheme]
  signature: Signature[Scheme]

func blck*(signed: SignedBlock): auto =
  signed.blck

func toBytes(blck: Block): seq[byte] =
  discard # TODO: serialization

func sign*(identity: Identity, blck: Block): auto =
  let signature = identity.sign(blck.toBytes)
  SignedBlock[Identity.Scheme](blck: blck, signature: signature)

func signer*(signed: SignedBlock): auto =
  signed.signature.signer(signed.blck.toBytes)
