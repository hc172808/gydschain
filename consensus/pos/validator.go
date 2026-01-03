package pos

type Validator struct {
	Address  string
	Stake    uint64
	Power    uint64
	Slashed  bool
	UnbondingHeight uint64
}
