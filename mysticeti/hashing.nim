type
  Hash*[Hashing] = object
    value: Hashing.Hash
  Hashing*[Hash] = object

func hash*(T: type Hashing, bytes: openArray[byte]): auto =
  mixin hash
  Hash[T](value: T.Hash.hash(bytes))

func `$`*(hash: Hash): string =
  $hash.value
