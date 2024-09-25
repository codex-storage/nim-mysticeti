import ./signing
import ./hashing
import ./committee

type Transaction* = object

type
  Block*[Signing, Hashing] = object
    author: CommitteeMember
    round: uint64
    parents: seq[BlockId[Signing, Hashing]]
    transactions: seq[Transaction]
  BlockId*[Signing, Hashing] = object
    author: CommitteeMember
    round: uint64
    hash: Hash[Hashing]

func new*(
  _: type Block,
  author: CommitteeMember,
  round: uint64,
  parents: seq[BlockId],
  transactions: seq[Transaction]
): auto =
  Block[BlockId.Signing, BlockId.Hashing](
    author: author,
    round: round,
    parents: parents,
    transactions: transactions
  )

func author*(blck: Block | BlockId): auto =
  blck.author

func round*(blck: Block | BlockId): uint64 =
  blck.round

func parents*(blck: Block): auto =
  blck.parents

func toBytes(blck: Block): seq[byte] =
  cast[seq[byte]]($blck) # TODO: proper serialization

func id*(blck: Block): auto =
  BlockId[Block.Signing, Block.Hashing](
    author: blck.author,
    round: blck.round,
    hash: Block.Hashing.hash(blck.toBytes)
  )

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
