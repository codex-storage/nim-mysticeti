type
  Hash*[Dependencies] = object
    value: Dependencies.Hashing.Hash
  Hashing*[Hash] = object

func hash*(T: type Hash, bytes: openArray[byte]): auto =
  mixin hash
  T(value: T.Dependencies.Hashing.Hash.hash(bytes))

func `$`*(hash: Hash): string =
  $hash.value
