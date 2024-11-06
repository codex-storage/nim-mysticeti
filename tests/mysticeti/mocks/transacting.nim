import mysticeti/dependencies/transacting

type
  MockTransaction = object
  MockTransacting* = Transacting[MockTransaction]

proc example*(_: type MockTransaction): MockTransaction =
  discard
