package core

type Address string

type Account struct {
    Address  Address
    Nonce    uint64
    Balances map[string]uint64
}
