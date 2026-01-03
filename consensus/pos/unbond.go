package pos

func (e *Engine) FinalizeUnbonding(accounts map[string]*Account) {
	for _, v := range e.State.Validators {
		if v.UnbondingHeight > 0 && e.State.Height >= v.UnbondingHeight {
			acc := accounts[string(v.Address)]
			acc.Balance["GYDS"] += acc.Unbonding
			acc.Unbonding = 0
			v.UnbondingHeight = 0
		}
	}
}
