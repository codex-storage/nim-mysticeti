import ../signing
import ./blck

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
