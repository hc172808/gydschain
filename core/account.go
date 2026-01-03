package core

import (
    "errors"
    "github.com/hc172808/gydschain/types"
)

type Ledger struct {
    Accounts map[types.Address]*types.Account
}

func NewLedger() *Ledger {
    return &Ledger{
        Accounts: make(map[types.Address]*types.Account),
    }
}

func (l *Ledger) GetAccount(addr types.Address) (*types.Account, error) {
    acc, ok := l.Accounts[addr]
    if !ok {
        return nil, errors.New("account not found")
    }
    return acc, nil
}

func (l *Ledger) UpdateBalance(addr types.Address, amount uint64) error {
    acc, err := l.GetAccount(addr)
    if err != nil {
        return err
    }
    acc.Balance += amount
    return nil
}
