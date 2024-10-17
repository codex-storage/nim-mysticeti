type CommitteeMember* = distinct int

proc `==`*(a, b: CommitteeMember): bool {.borrow.}
proc `$`*(member: CommitteeMember): string {.borrow.}
