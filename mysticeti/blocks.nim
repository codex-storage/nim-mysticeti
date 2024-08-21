import ./signing

type Transaction* = object

type
  Block*[Signing] = object
    author: Identifier[Signing]
    round: uint64
    parents: seq[BlockHash]
    transactions: seq[Transaction]
  BlockHash* = object

func new*[Signing](
  _: type Block[Signing],
  author: Identifier,
  round: uint64,
  parents: seq[BlockHash],
  transactions: seq[Transaction]
): Block[Signing] =
  Block[Signing](
    author: author,
    round: round,
    parents: parents,
    transactions: transactions
  )

func author*(blck: Block): auto =
  blck.author

func round*(blck: Block): uint64 =
  blck.round


type SignedBlock*[Signing] = object
  blck: Block[Signing]
  signature: Signature[Signing]

func blck*(signed: SignedBlock): auto =
  signed.blck

func toBytes(blck: Block): seq[byte] =
  discard # TODO: serialization

func sign*(identity: Identity, blck: Block): auto =
  let signature = identity.sign(blck.toBytes)
  SignedBlock[Identity.Signing](blck: blck, signature: signature)

func signer*(signed: SignedBlock): auto =
  signed.signature.signer(signed.blck.toBytes)
