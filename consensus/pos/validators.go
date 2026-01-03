package pos

import "github.com/hc172808/gydschain/core"

func (e *Engine) validator(addr core.Address) *Validator {
	for _, v := range e.State.Validators {
		if v.Address == addr {
			return v
		}
	}
	return nil
}

func (e *Engine) addOrIncreaseValidator(addr core.Address, amt uint64) {
	v := e.validator(addr)
	if v != nil {
		v.Stake += amt
		v.Power = v.Stake
		return
	}

	e.State.Validators = append(e.State.Validators, &Validator{
		Address: addr,
		Stake:   amt,
		Power:   amt,
	})
}
