package core

import (
	"errors"
	"fmt"
)

// MultiSigWallet represents a multisignature wallet
type MultiSigWallet struct {
	Owners  []string
	Balance uint64
	Quorum  int
}

// NewMultiSigWallet creates a new multisig wallet
func NewMultiSigWallet(owners []string, quorum int) (*MultiSigWallet, error) {
	if len(owners) == 0 {
		return nil, errors.New("owners list cannot be empty")
	}
	if quorum <= 0 || quorum > len(owners) {
		return nil, errors.New("invalid quorum")
	}
	return &MultiSigWallet{
		Owners:  owners,
		Balance: 0,
		Quorum:  quorum,
	}, nil
}

// Deposit adds funds to the wallet
func (w *MultiSigWallet) Deposit(amount uint64) {
	w.Balance += amount
	fmt.Printf("Deposited %d. New balance: %d\n", amount, w.Balance)
}

// Withdraw removes funds from the wallet if quorum is met
func (w *MultiSigWallet) Withdraw(amount uint64, approvals int) error {
	if approvals < w.Quorum {
		return errors.New("not enough approvals for withdrawal")
	}
	if amount > w.Balance {
		return errors.New("insufficient funds")
	}
	w.Balance -= amount
	fmt.Printf("Withdrew %d. New balance: %d\n", amount, w.Balance)
	return nil
}

// GetBalance returns the current balance
func (w *MultiSigWallet) GetBalance() uint64 {
	return w.Balance
}
