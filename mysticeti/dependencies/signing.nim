import ./hashing

type
  Identity*[Dependencies] = object
    value: Dependencies.Signing.Identity
  Identifier*[Dependencies] = object
    value: Dependencies.Signing.Identifier
  Signature*[Dependencies] = object
    value: Dependencies.Signing.Signature
  Signing*[Identity, Identifier, Signature] = object

proc init*(T: type Identity): T =
  mixin init
  T(value: T.Dependencies.Signing.Identity.init())

func identifier*(identity: Identity): auto =
  mixin identifier
  Identifier[Identity.Dependencies](value: identity.value.identifier)

func sign*(identity: Identity, hash: Hash): auto =
  mixin sign
  Signature[Identity.Dependencies](value: identity.value.sign(hash))

func signer*(signature: Signature, hash: Hash): auto =
  mixin signer
  Identifier[Signature.Dependencies](value: signature.value.signer(hash))

func `$`*(identity: Identity): string =
  $identity.value

func `$`*(identifier: Identifier): string =
  $identifier.value

func `$`*(signature: Signature): string =
  $signature.value
