package mining

import "github.com/hc172808/gydschain/core"

type RewardProof struct {
    Miner   core.Address
    Nonce   uint64
    Hash    []byte
    Work    uint64
}
