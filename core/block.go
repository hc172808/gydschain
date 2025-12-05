package core

import (
	"crypto/sha256"
	"encoding/hex"
	"time"
)

// Block represents a single block in the blockchain
type Block struct {
	Index        int           `json:"index"`
	Timestamp    int64         `json:"timestamp"`
	PreviousHash string        `json:"previous_hash"`
	Hash         string        `json:"hash"`
	Transactions []Transaction `json:"transactions"`
	Miner        string        `json:"miner"`
	Difficulty   int           `json:"difficulty"`
	Nonce        int64         `json:"nonce"`
}

// CalculateHash computes the SHA256 hash of the block
func (b *Block) CalculateHash() string {
	record := string(b.Index) + string(b.Timestamp) + b.PreviousHash + serializeTransactions(b.Transactions) +
		b.Miner + string(b.Difficulty) + string(b.Nonce)
	hash := sha256.New()
	hash.Write([]byte(record))
	return hex.EncodeToString(hash.Sum(nil))
}

// CreateGenesisBlock initializes the first block in the blockchain
func CreateGenesisBlock(adminWallet string) *Block {
	genesis := &Block{
		Index:        0,
		Timestamp:    time.Now().Unix(),
		PreviousHash: "0",
		Transactions: []Transaction{}, // Add initial mint transactions if needed
		Miner:        adminWallet,
		Difficulty:   1,
		Nonce:        0,
	}
	genesis.Hash = genesis.CalculateHash()
	return genesis
}

// Helper function to serialize transactions
func serializeTransactions(txs []Transaction) string {
	result := ""
	for _, tx := range txs {
		result += tx.Sender + tx.Recipient + string(tx.Amount) + string(tx.Fee) + string(tx.Nonce)
	}
	return result
}
