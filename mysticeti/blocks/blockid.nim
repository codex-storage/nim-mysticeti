import ../basics
import ../committee

type BlockId*[Dependencies] = object
  author: CommitteeMember
  round: uint64
  hash: Hash[Dependencies]

func new*(
  T: type BlockId,
  author: CommitteeMember,
  round: uint64,
  hash: Hash
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
