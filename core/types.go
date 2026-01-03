package core

type Address string

type Account struct {
	Address   Address
	Nonce     uint64
	Balance   map[string]uint64
	Staked    uint64
	Unbonding uint64
}

type Block struct {
	Height    uint64
	Timestamp int64
	Proposer  Address
}

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

type ErrString struct {
	S string
}

func (e *ErrString) Error() string {
	return e.S
}
