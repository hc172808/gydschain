package core

type Account struct {
	Address Address
	Nonce   uint64
	Balance map[string]uint64

	Staked    uint64
	Unbonding uint64
}
