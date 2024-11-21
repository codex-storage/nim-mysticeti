import ../committee

type BlockId*[Dependencies] = object
  author: CommitteeMember
  round: uint64
  hash: Dependencies.Hash

func new*[T: BlockId](
  _: type T,
  author: CommitteeMember,
  round: uint64,
  hash: T.Dependencies.Hash
): auto =
  T(
    author: author,
    round: round,
    hash: hash
  )

func author*(id: BlockId): auto =
  id.author

func round*(id: BlockId): uint64 =
  id.round

func hash*(blck: BlockId): auto =
  blck.hash
