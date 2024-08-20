type Identity* = object
type Identifier* = object

func init*(_: type Identity): Identity =
  Identity()

func identifier*(identity: Identity): Identifier =
  discard

type Signed*[T] = object
  value: T

func sign*[T](identity: Identity, value: T): Signed[T] =
  Signed[T](value: value)

func value*[T](signed: Signed[T]): T =
  signed.value

func signatories*[T](signed: Signed[T]): seq[Identifier] =
  discard
