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

func identifier*[Scheme](identity: Identity[Scheme]): Identifier[Scheme] =
  mixin identifier
  Identifier[Scheme](value: identity.value.identifier)

func sign*[Scheme](identity: Identity[Scheme], bytes: openArray[byte]): Signature[Scheme] =
  mixin sign
  Signature[Scheme](value: identity.value.sign(bytes))

func signer*[Scheme](signature: Signature[Scheme], bytes: openArray[byte]): Identifier[Scheme] =
  mixin signer
  Identifier[Scheme](value: signature.value.signer(bytes))
