package pos

import "github.com/hc172808/gydschain/core"

var (
	ErrStakeTooSmall     = &core.ErrString{"stake amount too small"}
	ErrInsufficientFunds = &core.ErrString{"insufficient funds"}
	ErrInsufficientStake = &core.ErrString{"insufficient stake"}
)

func (e *Engine) validator(addr string) *Validator {
	for _, v := range e.State.Validators {
		if v.Address == addr {
			return v
		}
	}
	return nil
}

func (e *Engine) addOrIncreaseValidator(addr string, amt uint64) {
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

func (e *Engine) ApplyStake(tx core.Transaction, acc *core.Account) error {
	if tx.Amount < MinValidatorStake {
		return ErrStakeTooSmall
	}
	if acc.Balance["GYDS"] < tx.Amount {
		return ErrInsufficientFunds
	}
	acc.Balance["GYDS"] -= tx.Amount
	acc.Staked += tx.Amount
	e.addOrIncreaseValidator(string(tx.From), tx.Amount)
	return nil
}

func (e *Engine) ApplyUnstake(tx core.Transaction, acc *core.Account) error {
	if acc.Staked < tx.Amount {
		return ErrInsufficientStake
	}
	acc.Staked -= tx.Amount
	acc.Unbonding += tx.Amount
	v := e.validator(string(tx.From))
	if v != nil {
		v.UnbondingHeight = e.State.Height + UnbondingPeriod
	}
	return nil
}

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
