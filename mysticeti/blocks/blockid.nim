import ../committee

type BlockId*[Hash] = object
  author: CommitteeMember
  round: uint64
  hash: Hash

func new*[Hash](
  _: type BlockId,
  author: CommitteeMember,
  round: uint64,
  hash: Hash
): auto =
  BlockId[Hash](
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
