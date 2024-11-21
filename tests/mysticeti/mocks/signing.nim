import std/random
import std/sequtils
import std/strutils
import mysticeti/dependencies/signing
import ./hashing

type
  Identity = object
    id: string
  Identifier = object
    id: string
  Signature = object
    signer: string
  MockSigning* = Signing[Identity, Identifier, Signature]

proc init*(_: type Identity): Identity =
  Identity(id: newSeqWith(32, rand(byte)).mapIt(it.toHex(2)).join())

func identifier*(identity: Identity): Identifier =
  Identifier(id: identity.id)

func sign*(identity: Identity; hash: MockHash): Signature =
  Signature(signer: identity.id)

func signer*(signature: Signature, hash: MockHash): Identifier =
  Identifier(id: signature.signer)
