import ./dependencies/hashing
import ./dependencies/signing

export hashing
export signing

type Dependencies*[Hashing, Signing] = object
