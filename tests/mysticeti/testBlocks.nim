import ./basics
import mysticeti
import mysticeti/blocks

suite "Blocks":

  type Identity = MockIdentity
  type SignedBlock = mysticeti.SignedBlock[MockDependencies]

  test "blocks can be signed":
    let signer = Identity.init
    let blck = MockBlock.example
    let signature = signer.sign(blck.id.hash)
    let signed = SignedBlock.init(blck, signer.identifier, signature)
    check signed.blck == blck
    check signed.signer == signer.identifier
    check signed.signature == signature

  test "block signature can be verified":
    let signer1, signer2 = Identity.init
    let blck = MockBlock.example
    let signature = signer1.sign(blck.id.hash)
    let signedCorrect = SignedBlock.init(blck, signer1.identifier, signature)
    let signedInvalid = SignedBlock.init(blck, signer2.identifier, signature)
    check signedCorrect.verifySignature()
    check not signedInvalid.verifySignature()
