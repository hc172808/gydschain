package pos

import "github.com/hc172808/gydschain/core"

func (e *Engine) FinalizeUnbonding(accounts map[string]*core.Account) {
	for _, v := range e.State.Validators {
		if v.UnbondingHeight > 0 && e.State.Height >= v.UnbondingHeight {
			acc := accounts[v.Address]
			if acc != nil {
				acc.Balance["GYDS"] += acc.Unbonding
				acc.Unbonding = 0
			}
			v.UnbondingHeight = 0
		}
	}
}
