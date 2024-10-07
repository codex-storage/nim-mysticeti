import ../committee
import ../hashing

type BlockId*[Hashing] = object
  author: CommitteeMember
  round: uint64
  hash: Hash[Hashing]

func new*(
  _: type BlockId,
  author: CommitteeMember,
  round: uint64,
  hash: Hash
): auto =
  BlockId[Hash.Hashing](
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
