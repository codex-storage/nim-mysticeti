type
  Identity*[Signing] = object
    value: Signing.Identity
  Identifier*[Signing] = object
    value: Signing.Identifier
  Signature*[Signing] = object
    value: Signing.Signature
  Signing*[Identity, Identifier, Signature] = object

proc init*[Signing](_: type Identity[Signing]): Identity[Signing] =
  mixin init
  Identity[Signing](value: Signing.Identity.init())

func identifier*(identity: Identity): auto =
  mixin identifier
  Identifier[Identity.Signing](value: identity.value.identifier)

func sign*(identity: Identity, bytes: openArray[byte]): auto =
  mixin sign
  Signature[Identity.Signing](value: identity.value.sign(bytes))

func signer*(signature: Signature, bytes: openArray[byte]): auto =
  mixin signer
  Identifier[Signature.Signing](value: signature.value.signer(bytes))

func `$`*(identity: Identity): string =
  $identity.value

func `$`*(identifier: Identifier): string =
  $identifier.value

func `$`*(signature: Signature): string =
  $signature.value
