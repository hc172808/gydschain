package tokens

import (
	"fmt"
	"log"
)

// Token represents a generic token
type Token struct {
	Name            string             `json:"name"`
	Symbol          string             `json:"symbol"`
	TotalSupply     float64            `json:"total_supply"`
	Circulating     float64            `json:"circulating"`
	Mintable        bool               `json:"mintable"`
	Owner           string             `json:"owner"`
	UpdateAuthority string             `json:"update_authority"`
	FreezeAuthority string             `json:"freeze_authority"`
	Holders         map[string]float64 `json:"holders"` // address → balance
}

// NewToken creates a new token instance
func NewToken(name, symbol, owner string, initialSupply float64, mintable bool) *Token {
	t := &Token{
		Name:            name,
		Symbol:          symbol,
		Owner:           owner,
		TotalSupply:     initialSupply,
		Circulating:     initialSupply,
		Mintable:        mintable,
		Holders:         map[string]float64{owner: initialSupply},
		UpdateAuthority: owner,
		FreezeAuthority: owner,
	}
	log.Printf("Token %s (%s) created for owner %s with supply %.2f\n", name, symbol, owner, initialSupply)
	return t
}

// Mint adds tokens to the owner's balance
func (t *Token) Mint(amount float64) error {
	if !t.Mintable {
		return fmt.Errorf("token %s is not mintable", t.Symbol)
	}
	t.TotalSupply += amount
	t.Circulating += amount
	t.Holders[t.Owner] += amount
	return nil
}

// Burn removes tokens from a holder's balance
func (t *Token) Burn(holder string, amount float64) error {
	if balance, ok := t.Holders[holder]; !ok || balance < amount {
		return fmt.Errorf("insufficient balance to burn")
	}
	t.Holders[holder] -= amount
	t.Circulating -= amount
	return nil
}

// Transfer moves tokens between holders
func (t *Token) Transfer(sender, recipient string, amount float64) error {
	if balance, ok := t.Holders[sender]; !ok || balance < amount {
		return fmt.Errorf("insufficient balance")
	}
	t.Holders[sender] -= amount
	t.Holders[recipient] += amount
	return nil
}

// GetBalance returns the balance of a specific address
func (t *Token) GetBalance(address string) float64 {
	if bal, ok := t.Holders[address]; ok {
		return bal
	}
	return 0
}
