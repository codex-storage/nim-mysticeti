import ../blocks

type
  BlockVerdict* {.pure.} = enum
    invalid
    incomplete
    correct
  BlockCheck*[Signing, Hashing] = object
    case verdict: BlockVerdict
    of invalid:
      reason: string
    of incomplete:
      missing: seq[BlockId[Hashing]]
    of correct:
      blck: CorrectBlock[Signing, Hashing]
  CorrectBlock*[Signing, Hashing] = distinct SignedBlock[Signing, Hashing]

func invalid*(T: type BlockCheck, reason: string): T =
  T(verdict: BlockVerdict.invalid, reason: reason)

func incomplete*(T: type BlockCheck; missing: seq[BlockId]): T =
  T(verdict: BlockVerdict.incomplete, missing: missing)

func correct*(T: type BlockCheck, signedBlock: SignedBlock): T =
  let blck = CorrectBlock[SignedBlock.Signing, SignedBlock.Hashing](signedBlock)
  T(verdict: BlockVerdict.correct, blck: blck)

func verdict*(check: BlockCheck): BlockVerdict =
  check.verdict

func reason*(check: BlockCheck): string =
  check.reason

func missing*(check: BlockCheck): auto =
  check.missing

func blck*(check: BlockCheck): auto =
  check.blck

func signedBlock*(correct: CorrectBlock): auto =
  SignedBlock[CorrectBlock.Signing, CorrectBlock.Hashing](correct)

func blck*(correct: CorrectBlock): auto =
  correct.signedBlock.blck
