package pos

type State struct {
	Validators []*Validator
	Height     uint64
	Round      uint64
}
