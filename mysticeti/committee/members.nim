type CommitteeMember* = distinct int

proc `==`*(a, b: CommitteeMember): bool {.borrow.}
