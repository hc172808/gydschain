package types

import "time"

type Address string

type Account struct {
    Address Address
    Balance uint64
    Nonce   uint64
}

type Transaction struct {
    From      Address
    To        Address
    AssetID   string
    Amount    uint64
    Fee       uint64
    Nonce     uint64
    Signature []byte
    Timestamp time.Time
}

type Validator struct {
    Address Address
    Stake   uint64
    Active  bool
}
