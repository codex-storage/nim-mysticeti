import ./basics
import mysticeti
import mysticeti/blocks

suite "Blocks":

  type Block = mysticeti.Block[MockDependencies]
  type BlockId = mysticeti.BlockId[MockDependencies.Hash]
  type Identity = MockDependencies.Identity
  type Transaction = MockDependencies.Transaction
  type Hash = MockDependencies.Hash
  type Serialization = MockDependencies.Serialization

  test "blocks have an author, a round, parents and transactions":
    let author = CommitteeMember.example
    let round = uint64.example
    let parents = seq[BlockId].example
    let transactions = seq[Transaction].example
    let blck = Block.new(author, round, parents, transactions)
    check blck.author == author
    check blck.round == round
    check blck.parents == parents.immutable
    check blck.transactions == transactions.immutable

  test "blocks have an id consisting of author, round and hash":
    let blck = Block.example
    let id = blck.id
    check id.author == blck.author
    check id.round == blck.round
    check id.hash == Hash.hash(Serialization.toBytes(blck))

  test "blocks can be signed":
    let signer = Identity.init
    let blck = Block.example
    let signed = blck.sign(signer)
    check signed.blck == blck
    check signed.signer == signer.identifier
