package pos

import "github.com/hc172808/gydschain/core"

type Validator struct {
    Address core.Address
    Stake   uint64
    Power   uint64
    Slashed bool
}
