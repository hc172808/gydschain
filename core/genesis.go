package core

import (
	"log"
	"time"
)

// CreateGenesis initializes the genesis block and returns the blockchain slice
func CreateGenesis(adminWallet string) []*Block {
	log.Println("Creating genesis block...")

	genesisBlock := &Block{
		Index:        0,
		Timestamp:    time.Now().Unix(),
		PreviousHash: "0",
		Transactions: []Transaction{
			{
				Sender:    "0",           // system
				Recipient: adminWallet,   // admin receives initial coins
				Amount:    1000000,       // initial GYDS supply
				Fee:       0,
				Nonce:     0,
				Memo:      "Genesis mint",
			},
		},
		Miner:      adminWallet,
		Difficulty: 1,
		Nonce:      0,
	}
	genesisBlock.Hash = genesisBlock.CalculateHash()

	// Return blockchain slice containing only the genesis block
	return []*Block{genesisBlock}
}
