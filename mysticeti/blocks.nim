import ./signing
import ./hashing

type Transaction* = object

type
  Block*[Signing, Hashing] = object
    author: Identifier[Signing]
    round: uint64
    parents: seq[Hash[Hashing]]
    transactions: seq[Transaction]

func new*(
  _: type Block,
  author: Identifier,
  round: uint64,
  parents: seq[Hash],
  transactions: seq[Transaction]
): auto =
  Block[Identifier.Signing, Hash.Hashing](
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

func toBytes(blck: Block): seq[byte] =
  cast[seq[byte]]($blck) # TODO: proper serialization

func blockHash*(blck: Block): auto =
  Block.Hashing.hash(blck.toBytes)

type SignedBlock*[Signing, Hashing] = object
  blck: Block[Signing, Hashing]
  signature: Signature[Signing]

func new*(_: type SignedBlock, blck: Block, signature: Signature): auto =
  SignedBlock[Block.Signing, Block.Hashing](blck: blck, signature: signature)

func blck*(signed: SignedBlock): auto =
  signed.blck

func sign*(identity: Identity, blck: Block): auto =
  let signature = identity.sign(blck.toBytes)
  SignedBlock.new(blck, signature)

func signer*(signed: SignedBlock): auto =
  signed.signature.signer(signed.blck.toBytes)
