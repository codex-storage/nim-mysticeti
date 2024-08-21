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

func author*[Scheme](blck: Block[Scheme]): Identifier[Scheme] =
  blck.author

func round*[Scheme](blck: Block[Scheme]): uint64 =
  blck.round


type SignedBlock*[Scheme] = object
  blck: Block[Scheme]
  signature: Signature[Scheme]

func blck*[Scheme](signed: SignedBlock[Scheme]): Block[Scheme] =
  signed.blck

func toBytes[Scheme](blck: Block[Scheme]): seq[byte] =
  discard # TODO: serialization

func sign*[Scheme](identity: Identity[Scheme], blck: Block[Scheme]): SignedBlock[Scheme] =
  let signature = identity.sign(blck.toBytes)
  SignedBlock[Scheme](blck: blck, signature: signature)

func signer*[Scheme](signed: SignedBlock[Scheme]): Identifier[Scheme] =
  signed.signature.signer(signed.blck.toBytes)
