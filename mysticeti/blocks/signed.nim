import ../basics
import ./blck
import ./blockid

type SignedBlock*[Dependencies] = object
  blck: Block[Dependencies]
  signature: Dependencies.Signature

func sign*(blck: Block, signer: Block.Dependencies.Identity): auto =
  mixin sign
  let signature = signer.sign(blck.id.hash)
  SignedBlock[Block.Dependencies](blck: blck, signature: signature)

func blck*(signed: SignedBlock): auto =
  signed.blck

func signer*(signed: SignedBlock): auto =
  mixin signer
  signed.signature.signer(signed.blck.id.hash)
