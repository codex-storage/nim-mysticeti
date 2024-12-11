import ../basics
import ./blockid

type SignedBlock*[Dependencies] = object
  blck: Dependencies.Block
  signer: Dependencies.Identifier
  signature: Dependencies.Signature

func init*[Dependencies](
  _: type SignedBlock[Dependencies];
  blck: Dependencies.Block,
  signer: Dependencies.Identifier,
  signature: Dependencies.Signature
): auto =
  SignedBlock[Dependencies](blck: blck, signer: signer, signature: signature)

func blck*(signed: SignedBlock): auto =
  signed.blck

func signer*(signed: SignedBlock): auto =
  signed.signer

func signature*(signed: SignedBlock): auto =
  signed.signature

func verifySignature*(signed: SignedBlock): bool =
  mixin verify
  mixin id
  let signature = signed.signature
  let signer = signed.signer
  let blck = signed.blck
  signature.verify(signer, blck.id.hash)
