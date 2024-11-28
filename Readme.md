Mysticeti consensus algorithm
=============================

An implementation of [Mysticeti][1], a highly performant DAG based Byzantine
consensus protocol. This is just the bare consensus algorithm, you need to bring
your own transaction types, networking, serialization, and cryptographic hashing
and signature schemes.

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

A Validator can work with any transaction type and any serialization, hashing
and signature scheme. The Validator type takes a single generic argument called
`Dependencies`, and this is used to inject the implementations of these
dependencies at compile time.

```nim
import mysticeti

# gather all dependencies:
type MyDependencies = Dependencies[
  MyTransaction,   # provide your own transaction type here
  MySerialization, # provide your own serialization scheme here
  MyHash,          # provide your own hashing scheme here
  MyIdentity       # provide your own private key implementation here
  MyIdentifier     # provide your own public key implementation here
  MySignature      # provide your own signature scheme here
]

# create a validator type using these dependencies:
type Validator = mysticeti.Validator[MyDependencies]
```

The Validator implementation has certain expectations about each of these
dependencies, and they are detailed below.

### Transaction type

A transaction type can be anything, as long as it can be serialized as part of
the block serialization.

  * `Transaction`: represents a transaction that can be added to a block

A toy example that shows how to provide this type can found in
[`mocks/transaction.nim`](tests/mysticeti/mocks/transaction.nim).

### Serialization

A serialization scheme for blocks is required so that a block can be converted
to bytes, which can then be hashed and signed. The Validator implementation
expects the following type and function to be present:

  * `Serialization`: represents a serialization scheme
  * `Serialization.toBytes(block)`: converts a block into bytes

A toy example that shows how to provide this type and function can be found in
[`mocks/serialization.nim`](tests/mysticeti/mocks/serialization.nim).

### Hashing

A cryptographic hashing scheme is required so that a block hash can be created
that uniquely identifies the block. The Validator implementation expects a
`Hash` type and the following functions:

   * `Hash`: represents a digest from a hashing function
   * `Hash.hash(bytes)`: digests the bytes to create a hash
   * `==`: checks whether two hashes are equal

A toy example that shows how to provide this type and these functions can found
in [`mocks/hashing.nim`](tests/mysticeti/mocks/hashing.nim).

### Signature scheme

A cryptographic signature scheme is required so that validators can sign off on
the blocks that they propose. The Validator implementation expects the following
types and functions to be present:

   * `Identity`: represents the private key that a validator uses to sign
   * `Identifier`: represents a public key that is used to identify a validator
   * `Signature`: represents a block signature
   * `identity.identifier`: the public key that is derived from the private key
   * `identity.sign(hash)`: signs the hash and returns a Signature
   * `signature.signer(hash)`: returns the signer that signed the hash
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

A validator can be instantiated using its identity and the committee that it is
part of:

```nim
let validator = Validator.new(identity, committee)
```

> Note: the identity that you pass to the validator needs to have its
> corresponding identifier present in the commitee

Running a Validator
-------------------

The Mysticeti protocol works in rounds. Each round all validators propose new
blocks, and receive the blocks that other validators proposed. Because these
blocks reference each other, they form a graph (DAG). Each validator looks at
this graph and determines which blocks are agreed upon by the consensus protocol
and commits them.

### Proposing blocks

To propose a new block of transactions, invoke the `propose` function:

```nim
import questionable/results

if signedBlock =? validator.propose(transactions):
  # send the signed block to other validators
```

The `propose` function returns a
[`Result`](https://github.com/codex-storage/questionable) that either contains a
signed block of transactions, or an error. Errors may occur because a block was
already proposed this round, or because there were not enough parent blocks to
construct a valid block.

### Receiving blocks

When you recieve a signed block from another validator, you first need to check
its validity by invoking the `check` function:

```nim
let checked = validator.check(signedBlock)
```

This gives you a `BlockCheck` object containing a `verdict` about the block's
correctness. The verdict can be either `correct`, `invalid`, or `incomplete`.

When the verdict is `correct`, you can pass the correct block into the `receive`
function:

```nim
if checked.verdict == BlockVerdict.correct:
  validator.receive(checked.blck)
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

The Mysticeti protocol uses a threshold logical clock to move from one round to
the next. This means that each validator moves to the next round when it's seen
enough blocks in the current round to represent >2/3 of the stake.

Additionaly, the protocol mandates that all validators wait for the primary
proposer of the round (with a timeout), before moving to the next round.

To move to the next round, invoke the `nextRound` function:

```nim
validator.nextRound()
```

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
