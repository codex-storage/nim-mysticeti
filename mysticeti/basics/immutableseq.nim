type ImmutableSeq*[Element] = ref object
  ## Encapsulates a sequence, so that it no longer can be
  ## modified, and can be passed by reference to avoid copying.
  elements: seq[Element]

func immutable*[Element](sequence: seq[Element]): ImmutableSeq[Element] =
  ImmutableSeq[Element](elements: sequence)

func copy*(sequence: ImmutableSeq): auto =
  sequence.elements

iterator items*(sequence: ImmutableSeq): auto =
  for element in sequence.elements:
    yield element

func len*(sequence: ImmutableSeq): int =
  sequence.elements.len

func `[]`*(sequence: ImmutableSeq, index: int): auto =
  sequence.elements[index]

func contains*[Element](sequence: ImmutableSeq[Element], element: Element): bool =
  sequence.elements.contains(element)

func `==`*(a, b: ImmutableSeq): bool =
  a.elements == b.elements

