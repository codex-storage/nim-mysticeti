import ../basics
import ../blocks

type
  BlockVerdict* {.pure.} = enum
    invalid
    incomplete
    correct
  BlockCheck*[Dependencies] = object
    case verdict: BlockVerdict
    of invalid:
      reason: string
    of incomplete:
      missing: seq[typeof(Dependencies.Block.default.id)]
    of correct:
      blck: CorrectBlock[Dependencies]
  CorrectBlock*[Dependencies] = distinct SignedBlock[Dependencies]

func invalid*(T: type BlockCheck, reason: string): T =
  T(verdict: BlockVerdict.invalid, reason: reason)

func incomplete*(T: type BlockCheck; missing: seq[BlockId]): T =
  T(verdict: BlockVerdict.incomplete, missing: missing)

func correct*(T: type BlockCheck, signedBlock: SignedBlock): T =
  let blck = CorrectBlock[SignedBlock.Dependencies](signedBlock)
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
  SignedBlock[CorrectBlock.Dependencies](correct)

func blck*(correct: CorrectBlock): auto =
  correct.signedBlock.blck
