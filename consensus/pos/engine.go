package pos

import "github.com/hc172808/gydschain/core"

// Engine handles PoS consensus
type Engine struct {
	State *State
}

// NewEngine creates an empty PoS engine
func NewEngine() *Engine {
	return &Engine{
		State: NewState(),
	}
}

// NewEngineFromGenesis initializes engine from genesis validators
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

// NewState creates empty PoS state
func NewState() *State {
	return &State{}
}
