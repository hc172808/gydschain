package main

import (
	"log"
	"time"

	"gyds-chain/core"
)

func main() {
	// Load config
	config, err := core.LoadConfig("./scripts/config.json")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Create genesis block and blockchain
	genesis := core.CreateGenesisBlock(config.AdminWallet)
	blockchain := core.NewBlockchain([]*core.Block{genesis}, config.BlockTime)
	log.Println("✅ Blockchain initialized with genesis block")

	// Simple CPU mining loop
	if config.EnableMining {
		log.Println("⛏ Mining enabled")
		for {
			time.Sleep(time.Duration(blockchain.BlockTime) * time.Second)
			block := blockchain.MinePendingTransactions(config.AdminWallet)
			if block != nil {
				log.Printf("🎉 New block mined: %d", block.Index)
			}
		}
	} else {
		log.Println("⚡ Mining disabled")
	}

	select {} // keep running
}
