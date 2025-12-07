package main

import (
	"fmt"
	"log"
	"time"

	"gyds-chain/core"
	"gyds-chain/p2p"
	"gyds-chain/rpc"
)

func main() {
	// Load config
	config, err := core.LoadConfig("/opt/gyds-chain/scripts/config.json")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Create genesis block and blockchain
	genesis := core.CreateGenesisBlock(config.AdminWallet)
	blockchain := core.NewBlockchain([]*core.Block{genesis}, config.BlockTime)
	log.Println("✅ Blockchain initialized with genesis block")

	// Start P2P node
	node := p2p.NewNode("0.0.0.0", 30303)
	go node.StartServer()
	log.Println("🌐 P2P node started")

	// Start RPC server
	rpcServer := rpc.NewRPCServer(blockchain, config.TrustedRPCIP)
	go rpcServer.Start(config.RPCPort)
	log.Println("🖥 RPC server started")

	// CPU mining loop
	if config.EnableMining {
		log.Println("⛏ Mining enabled")
		for {
			time.Sleep(time.Duration(blockchain.BlockTime) * time.Second)
			block := blockchain.MinePendingTransactions(config.AdminWallet)
			if block != nil {
				log.Printf("🎉 New block mined: %d", block.Index)
				node.Broadcast(fmt.Sprintf("New block %d mined", block.Index))
			}
		}
	} else {
		log.Println("⚡ Mining disabled")
	}

	select {} // keep main running
}

