import ./signing
import ./hashing
import ./committee

type Transaction* = object

type
  Block*[Hashing] = object
    author: CommitteeMember
    round: uint64
    parents: seq[BlockId[Hashing]]
    transactions: seq[Transaction]
  BlockId*[Hashing] = object
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
  Block[BlockId.Hashing](
    author: author,
    round: round,
    parents: parents,
    transactions: transactions
  )

func new*(
  _: type BlockId,
  author: CommitteeMember,
  round: uint64,
  hash: Hash
): auto =
  BlockId[Hash.Hashing](
    author: author,
    round: round,
    hash: hash
  )

func author*(blck: Block | BlockId): auto =
  blck.author

func round*(blck: Block | BlockId): uint64 =
  blck.round

func parents*(blck: Block): auto =
  blck.parents

func transactions*(blck: Block): auto =
  blck.transactions

func hash*(blck: BlockId): auto =
  blck.hash

func toBytes*(blck: Block): seq[byte] =
  cast[seq[byte]]($blck) # TODO: proper serialization

func id*(blck: Block): auto =
  BlockId[Block.Hashing](
    author: blck.author,
    round: blck.round,
    hash: Block.Hashing.hash(blck.toBytes)
  )

type SignedBlock*[Signing, Hashing] = object
  blck: Block[Hashing]
  signature: Signature[Signing]

func new*(_: type SignedBlock, blck: Block, signature: Signature): auto =
  SignedBlock[Signature.Signing, Block.Hashing](blck: blck, signature: signature)

func blck*(signed: SignedBlock): auto =
  signed.blck

func sign*(identity: Identity, blck: Block): auto =
  let signature = identity.sign(blck.toBytes)
  SignedBlock.new(blck, signature)

func signer*(signed: SignedBlock): auto =
  signed.signature.signer(signed.blck.toBytes)
