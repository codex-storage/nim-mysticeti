import std/hashes

type
  Identity* = ref object of RootObj
    scheme: IdentityScheme
  Identifier* = ref object of RootObj
    scheme: IdentityScheme
  Signature* = ref object of RootObj
    scheme: IdentityScheme
  IdentityScheme* = ref object
    name: string
    identity: proc: Identity
    identifier: proc(identity: Identity): Identifier {.noSideEffect.}
    equals: proc(a, b: Identifier): bool {.noSideEffect.}
    sign: proc(identity: Identity, bytes: openArray[byte]): Signature {.noSideEffect.}
    signer: proc(signature: Signature, bytes: openArray[byte]): Identifier {.noSideEffect.}
    toString: proc(identifier: Identifier): string {.noSideEffect.}
    hash: proc(identifier: Identifier): Hash {.noSideEffect.}

proc init*(_: type Identity, scheme: IdentityScheme): Identity =
  var identity = scheme.identity()
  identity.scheme = scheme
  identity

func identifier*(identity: Identity): Identifier =
  var identifier = identity.scheme.identifier(identity)
  identifier.scheme = identity.scheme
  identifier

func `==`*(a, b: Identifier): bool =
  a.scheme == b.scheme and a.scheme.equals(a, b)

func sign*(identity: Identity, bytes: openArray[byte]): Signature =
  var signature = identity.scheme.sign(identity, bytes)
  signature.scheme = identity.scheme
  signature

func signer*(signature: Signature, bytes: openArray[byte]): Identifier =
  var identifier = signature.scheme.signer(signature, bytes)
  identifier.scheme = signature.scheme
  identifier

func `$`*(identifier: Identifier): string =
  identifier.scheme.toString(identifier)

func hash*(identifier: Identifier): Hash =
  identifier.scheme.hash(identifier)

func new*(
  _: type IdentityScheme,
    name: string,
    identity: proc: Identity,
    identifier: proc(identity: Identity): Identifier {.noSideEffect.},
    equals: proc(a, b: Identifier): bool {.noSideEffect.},
    sign: proc(identity: Identity, bytes: openArray[byte]): Signature {.noSideEffect.},
    signer: proc(signature: Signature, bytes: openArray[byte]): Identifier {.noSideEffect.},
    toString: proc(identifier: Identifier): string {.noSideEffect.},
    hash: proc(identifier: Identifier): Hash {.noSideEffect.}
): IdentityScheme =
  IdentityScheme(
    name: name,
    identity: identity,
    identifier: identifier,
    equals: equals,
    sign: sign,
    signer: signer,
    toString: toString,
    hash: hash
  )
