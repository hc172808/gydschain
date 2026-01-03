package pos

import (
    "github.com/hc172808/gydschain/types"
)

type PoSEngine struct {
    Validators map[types.Address]*types.Validator
}

func NewPoSEngine() *PoSEngine {
    return &PoSEngine{
        Validators: make(map[types.Address]*types.Validator),
    }
}

func (p *PoSEngine) Stake(addr types.Address, amount uint64) {
    val, ok := p.Validators[addr]
    if !ok {
        p.Validators[addr] = &types.Validator{
            Address: addr,
            Stake:   amount,
            Active:  true,
        }
        return
    }
    val.Stake += amount
}
