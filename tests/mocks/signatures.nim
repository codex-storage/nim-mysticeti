import std/random
import std/sequtils
import std/strutils
import mysticeti/signatures

type
  Identity = object
    id: string
  Identifier = object
    id: string
  Signature = object
    signer: string
  MockSignatureScheme* = SignatureScheme[Identity, Identifier, Signature]

proc init*(_: type Identity): Identity =
  Identity(id: newSeqWith(32, rand(byte)).mapIt(it.toHex(2)).join())

func identifier*(identity: Identity): Identifier =
  Identifier(id: identity.id)

func sign*(identity: Identity, bytes: openArray[byte]): Signature =
  Signature(signer: identity.id)

func signer*(signature: Signature, bytes: openArray[byte]): Identifier =
  Identifier(id: signature.signer)
