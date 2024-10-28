import ../blocks

type
  BlockVerdict* {.pure.} = enum
    invalid
    incomplete
    correct
  BlockCheck*[Hashing] = object
    case verdict: BlockVerdict
    of invalid:
      reason: string
    of incomplete:
      missing: seq[BlockId[Hashing]]
    of correct:
      blck: CorrectBlock[Hashing]
  CorrectBlock*[Hashing] = distinct Block[Hashing]

func invalid*(T: type BlockCheck, reason: string): T =
  T(verdict: BlockVerdict.invalid, reason: reason)

func incomplete*(T: type BlockCheck; missing: seq[BlockId]): T =
  T(verdict: BlockVerdict.incomplete, missing: missing)

func correct*(T: type BlockCheck, blck: Block): T =
  T(verdict: BlockVerdict.correct, blck: CorrectBlock[Block.Hashing](blck))

func verdict*(check: BlockCheck): BlockVerdict =
  check.verdict

func reason*(check: BlockCheck): string =
  check.reason

func missing*(check: BlockCheck): auto =
  check.missing

func blck*(check: BlockCheck): auto =
  check.blck

func blck*(correct: CorrectBlock): auto =
  Block[CorrectBlock.Hashing](correct)
