package pos

import "github.com/hc172808/gydschain/core"

type Engine struct {
	State *State
}

func NewEngine() *Engine {
	return &Engine{
		State: NewState(),
	}
}

func NewEngineFromGenesis(g *core.Genesis) *Engine {
	state := NewState()
	for _, v := range g.Validators {
		state.Validators = append(state.Validators, &Validator{
			Address: v.Address,
			Stake:   v.Stake,
			Power:   v.Stake,
		})
	}
	return &Engine{State: state}
}

func NewState() *State {
	return &State{}
}

func (s *State) Proposer() *Validator {
	if len(s.Validators) == 0 {
		return nil
	}
	index := int(s.Height % uint64(len(s.Validators)))
	return s.Validators[index]
}
