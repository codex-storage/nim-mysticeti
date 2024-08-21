type
  Identity*[Scheme] = object
    value: Scheme.Identity
  Identifier*[Scheme] = object
    value: Scheme.Identifier
  Signature*[Scheme] = object
    value: Scheme.Signature
  SignatureScheme*[Identity, Identifier, Signature] = object

proc init*[Scheme](_: type Identity[Scheme]): Identity[Scheme] =
  mixin init
  Identity[Scheme](value: Scheme.Identity.init())

func identifier*(identity: Identity): auto =
  mixin identifier
  Identifier[Identity.Scheme](value: identity.value.identifier)

func sign*(identity: Identity, bytes: openArray[byte]): auto =
  mixin sign
  Signature[Identity.Scheme](value: identity.value.sign(bytes))

func signer*(signature: Signature, bytes: openArray[byte]): auto =
  mixin signer
  Identifier[Signature.Scheme](value: signature.value.signer(bytes))
