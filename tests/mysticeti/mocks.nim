import mysticeti/dependencies
import ./mocks/signing
import ./mocks/hashing

export signing
export hashing

type MockDependencies* = Dependencies[MockSigning, MockHashing]
