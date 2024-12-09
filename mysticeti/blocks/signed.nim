import ../basics
import ./blck
import ./blockid

type SignedBlock*[Dependencies] = object
  blck: Block[Dependencies]
  signature: Dependencies.Signature

func init*(
  _: type SignedBlock,
  blck: Block,
  signature: Block.Dependencies.Signature
): auto =
  SignedBlock[Block.Dependencies](blck: blck, signature: signature)

func blck*(signed: SignedBlock): auto =
  signed.blck

func signer*(signed: SignedBlock): auto =
  mixin signer
  signed.signature.signer(signed.blck.id.hash)
