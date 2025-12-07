package core

import (
	"crypto/sha256"
	"encoding/hex"
	"strconv"
	"time"
)

type Block struct {
	Index        int
	Timestamp    int64
	PreviousHash string
	Hash         string
	Transactions []Transaction
	Miner        string
	Difficulty   int
	Nonce        int64
}

// CalculateHash computes the SHA256 hash of the block
func (b *Block) CalculateHash() string {
	record := strconv.Itoa(b.Index) +
		strconv.FormatInt(b.Timestamp, 10) +
		b.PreviousHash +
		serializeTransactions(b.Transactions) +
		b.Miner +
		strconv.Itoa(b.Difficulty) +
		strconv.FormatInt(b.Nonce, 10)

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
		Transactions: []Transaction{},
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
		amountStr := strconv.FormatFloat(tx.Amount, 'f', 6, 64)
		feeStr := strconv.FormatFloat(tx.Fee, 'f', 6, 64)
		nonceStr := strconv.FormatInt(tx.Nonce, 10)
		result += tx.Sender + tx.Recipient + amountStr + feeStr + nonceStr
	}
	return result
}
