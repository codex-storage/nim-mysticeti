import ../basics
import ./blockid

type SignedBlock*[Dependencies] = object
  blck: Dependencies.Block
  signature: Dependencies.Signature

func init*[Dependencies](
  _: type SignedBlock[Dependencies];
  blck: Dependencies.Block,
  signature: Dependencies.Signature
): auto =
  SignedBlock[Dependencies](blck: blck, signature: signature)

func blck*(signed: SignedBlock): auto =
  signed.blck

func signer*(signed: SignedBlock): auto =
  mixin signer
  mixin id
  signed.signature.signer(signed.blck.id.hash)
