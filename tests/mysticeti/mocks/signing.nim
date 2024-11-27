import std/random
import std/sequtils
import std/strutils
import ./hashing

type
  MockIdentity* = object
    id: string
  MockIdentifier* = object
    id: string
  MockSignature* = object
    signer: string

proc init*(_: type MockIdentity): MockIdentity =
  MockIdentity(id: newSeqWith(32, rand(byte)).mapIt(it.toHex(2)).join())

func identifier*(identity: MockIdentity): MockIdentifier =
  MockIdentifier(id: identity.id)

func sign*(identity: MockIdentity; hash: MockHash): MockSignature =
  MockSignature(signer: identity.id)

func signer*(signature: MockSignature, hash: MockHash): MockIdentifier =
  MockIdentifier(id: signature.signer)
