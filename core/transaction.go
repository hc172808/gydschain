package core

// Transaction represents a blockchain transaction
type Transaction struct {
	Sender    string  `json:"sender"`
	Recipient string  `json:"recipient"`
	Amount    float64 `json:"amount"`
	Fee       float64 `json:"fee"`
	Nonce     int64   `json:"nonce"`
	Memo      string  `json:"memo,omitempty"` // optional field for extra info
}

// NewTransaction creates a new transaction object
func NewTransaction(sender, recipient string, amount, fee float64, nonce int64) Transaction {
	return Transaction{
		Sender:    sender,
		Recipient: recipient,
		Amount:    amount,
		Fee:       fee,
		Nonce:     nonce,
	}
}
