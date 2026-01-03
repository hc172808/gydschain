package core

type TxType uint8

const (
	TxTransfer TxType = iota
	TxStake
	TxUnstake
)

type Transaction struct {
	Type      TxType
	From      Address
	Amount    uint64
	Fee       uint64
	Nonce     uint64
	Signature []byte
}
