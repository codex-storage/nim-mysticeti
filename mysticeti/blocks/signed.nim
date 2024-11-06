import ../basics
import ./blck

type SignedBlock*[Dependencies] = object
  blck: Block[Dependencies]
  signature: Signature[Dependencies]

func new*(_: type SignedBlock, blck: Block, signature: Signature): auto =
  SignedBlock[Block.Dependencies](blck: blck, signature: signature)

func blck*(signed: SignedBlock): auto =
  signed.blck

func sign*(identity: Identity, blck: Block): auto =
  let signature = identity.sign(blck.toBytes)
  SignedBlock.new(blck, signature)

func signer*(signed: SignedBlock): auto =
  signed.signature.signer(signed.blck.toBytes)
