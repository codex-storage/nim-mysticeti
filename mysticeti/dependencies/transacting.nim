type
  Transaction*[Dependencies] = object
    value: Dependencies.Transacting.Transaction
  Transacting*[Transaction] = object

func init*[T: Transaction](_: type T, value: T.Dependencies.Transacting.Transaction): T =
  T(value: value)

func `$`*(transaction: Transaction): string =
  $transaction.value
