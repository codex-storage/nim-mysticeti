import std/random
import std/sequtils
import std/strutils
import std/hashes
import mysticeti/identity

type
  MockIdentity = ref object of Identity
    id: string
  MockIdentifier = ref object of Identifier
    id: string
  MockSignature = ref object of Signature
    signer: string

proc mockIdentity: Identity =
  let id = newSeqWith(32, rand(byte)).mapIt(it.toHex(2)).join()
  MockIdentity(id: id)

func mockIdentifier(identity: Identity): Identifier =
  let id = MockIdentity(identity).id
  MockIdentifier(id: id)

func mockEquals(a, b: Identifier): bool =
  MockIdentifier(a).id == MockIdentifier(b).id

func mockSign(identity: Identity, bytes: openArray[byte]): Signature =
  let id = MockIdentity(identity).id
  MockSignature(signer: id)

func mockSigner(bytes: openArray[byte], signature: Signature): Identifier =
  let signer = MockSignature(signature).signer
  MockIdentifier(id: signer)

func mockHash(identifier: Identifier): Hash =
  MockIdentifier(identifier).id.hash

let mockIdentityScheme* = IdentityScheme.new(
  "mock-identity-scheme",
  mockIdentity,
  mockIdentifier,
  mockEquals,
  mockSign,
  mockSigner,
  mockHash
)
