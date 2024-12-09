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
    let signed = SignedBlock.init(blck, signature)
    check signed.blck == blck
    check signed.signer == signer.identifier
