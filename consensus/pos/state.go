package pos

import "github.com/hc172808/gydschain/core"

type State struct {
	Validators []*Validator
	Height     uint64
	Round      uint64
}

func NewState() *State {
	return &State{}
}
