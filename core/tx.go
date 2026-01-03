package core

type Transaction struct {
    From      Address
    To        Address
    AssetID  string
    Amount   uint64
    Fee      uint64
    Nonce    uint64
    Signature []byte
}
