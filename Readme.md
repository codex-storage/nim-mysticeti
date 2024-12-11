Mysticeti consensus algorithm
=============================

An implementation of [Mysticeti][1], a highly performant DAG based Byzantine
consensus protocol. This is just the bare consensus algorithm, you need to bring
your own transaction types, networking, hashing and signature schemes.

The current implementation only supports the Mysticeti-C protocol, without the
Mysticeti-FPC fast path extension.

This is very much a work in progress; expect to see many things that are
incomplete or wrong. Use at your own risk.

[1]: https://arxiv.org/abs/2310.14821

Installation
------------

Use the [Nimble][2] package manager to add `mysticeti` to an existing project.
Add the following to its .nimble file:

```nim
requires "https://github.com/codex-storage/nim-mysticeti >= 0.1.0 & < 0.2.0"
```

> Note: requires at least Nim version 2.2.0

[2]: https://github.com/nim-lang/nimble

Dependencies
------------

A Validator can work with any transaction type and any signature scheme. The
Validator type takes a single generic argument called `Dependencies`, and this
is used to inject the implementations of these dependencies at compile time.

```nim
import mysticeti

# gather all dependencies:
type MyDependencies = Dependencies[
  Block,           # provide your own type for blocks of transactions here
  MyIdentifier     # provide your own public key implementation here
  MySignature      # provide your own cryptographic signature scheme here
]

# create a validator type using these dependencies:
type Validator = mysticeti.Validator[MyDependencies]
```

The Validator implementation has certain expectations about each of these
dependencies, and they are detailed below.

### Blocks

The validator expects a `Block` type that support the following functions:

  * `Block`: represents a block of transactions
  * `Block.author`: returns the committee member that authored the block
  * `Block.round`: returns the consensus round for which the block was produced
  * `Block.parents`: returns the parent blocks for this block
  * `Block.id`: returns a BlockId that uniquely identifies the block

A toy example that shows how to provide this type can found in
[`mocks/blck.nim`](tests/mysticeti/mocks/blck.nim).

### Signature scheme

A cryptographic signature scheme is required so that validators can sign off on
the blocks that they propose. The Validator implementation expects the following
types and functions to be present:

   * `Identifier`: represents a public key that is used to identify a validator
   * `Signature`: represents a block signature
   * `signature.verify(identifier, hash)`: checks that the signature is correct
   * `==`: checks whether two identifiers or two signatures are equal

A toy example that shows how to provide these types and functions can found in
[`mocks/signing.nim`](tests/mysticeti/mocks/signing.nim).

Instantiating a Validator
-------------------------

Each validator node in the network has its own identity. This usually takes the
form of a cryptographic private/public key pair. The validator uses the private
key to sign off on blocks, and the public key to identify itself to other
validators.

Validators form a committee, and each of them has voting power according to
their stake in the network. How this committee is formed, and how the stakes are
determined is outside the responsibility of this library. A validator instance
is simply informed about the members and stakes through a `Committee` object.

```nim
let committee = Committee.new({
  identifier1: 1/8  # validator with public key `identifier1` has 1/8 of the total stake
  identifier2: 1/2  # validator with public key `identifier2` has 1/2 of the total stake
  identifier3: 1/4  # validator with public key `identifier3` has 1/4 of the total stake
  identifier4: 1/8  # validator with public key `identifier4` has 1/8 of the total stake
})
```

A validator can be instantiated using its identifier (public key) and the
committee that it is part of:

```nim
let validator = Validator.new(identifier, committee)
```

> Note: the identifier that you pass to the validator needs to be present in the
> committee

Running a Validator
-------------------

The Mysticeti protocol works in rounds. Each round all validators propose new
blocks, and receive the blocks that other validators proposed. Because these
blocks reference each other, they form a graph (DAG). Each validator looks at
this graph and determines which blocks are agreed upon by the consensus protocol
and commits them.

### Proposing blocks

To propose a new block of transactions, create an instance of the `Block` type.
The `author`, `round` and `parents` fields of the `Block` can be populated
through calls to the validator:

```nim
let author = validator.membership
let round = validator.round
let parents = validator.parentBlocks
let blck = # create block instance using author, round and parents
```

Then you can sign the block hash, and use it to create a `SignedBlock` instance.

```nim
let blockHash = blck.id.hash
let signature = # create cryptographic signature of the block hash
let signedBlock = SignedBlock.init(blck, signature)
```

Then you should add the block to your validator and send it to the other
validators. Adding your own proposed block to your validator follows the same
flow as adding blocks that you received from other validators:

### Receiving blocks

When you recieve a signed block from another validator, you first need to check
its validity by invoking the `check` function:

```nim
let checked = validator.check(signedBlock)
```

This gives you a `BlockCheck` object containing a `verdict` about the block's
correctness. The verdict can be either `correct`, `invalid`, or `incomplete`.

When the verdict is `correct`, you can pass the correct block into the `add`
function:

```nim
if checked.verdict == BlockVerdict.correct:
  validator.add(checked.blck)
```

When the verdict is `invalid`, the received block should be ignored:

```nim
if checked.verdict == BlockVerdict.invalid:
  echo "ignoring block, reason: ", checked.reason
```

When the verdict is `incomplete` that means that some of the parent blocks are
unknown to the validator. It should then ask the validator that sent the block
for the missing parent blocks.

```nim
if checked.verdict == BlockVerdict.incomplete:
  let missing = checked.missing # the block ids of the missing parent blocks
  # ask sender for missing blocks
```

### Moving to the next round

The validator uses a threshold logical clock to move from one round to the next.
This means it moves to the next round when it's seen enough blocks in the
current round to represent >2/3 of the stake.

Additionaly, the protocol mandates that all validators wait for the primary
proposer of the round (with a timeout), before creating their own blocks.

The primary proposer for the current round can be retrieved from the validator:

```nim
let primaryProposer = validator.primaryProposer # changes each round
```

Sequencing
----------

The outcome of the consensus algorithm is a sequence of blocks that is
guaranteed to be the same for all validators. This sequence of committed blocks can be accessed through the `committed`
iterator:

```nim
for blck in validator.committed:
  let transactions = blck.transactions
  # execute transactions
```

The validator only keeps track of rounds that have blocks that are not yet
committed. Calling the `committed` iterator allows the validator to clean up
resources for older rounds.

Thanks
------

Many thanks to [Mystenlabs][5] (no affiliation) and the authors of the [Mysticeti
paper][1].

References
----------

  * [Mysticeti research paper][1]
  * [Presentation on the Mysticeti protocol][3]
  * [Reference implementation in Rust][4]

[3]: https://www.youtube.com/watch?v=wRXhxB0mR8Y
[4]: https://github.com/mystenlabs/mysticeti
[5]: https://www.mystenlabs.com/
