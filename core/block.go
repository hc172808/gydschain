package core

type Block struct {
    Height     uint64
    PrevHash   []byte
    Timestamp  int64
    Proposer   Address
    Txs        []Transaction
    Signatures map[Address][]byte
}
