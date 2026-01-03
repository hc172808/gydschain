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
