package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"gyds-chain/core"
	"gyds-chain/p2p"
	"gyds-chain/rpc"
)

func main() {
	// Command-line flags
	configPath := flag.String("config", "./scripts/config.json", "Path to config file")
	flag.Parse()

	// Load node configuration
	config, err := core.LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Create genesis block and blockchain
	genesis := core.CreateGenesis(config.AdminWallet)
	blockchain := core.NewBlockchain(genesis, config.BlockTime)
	log.Println("Blockchain initialized with genesis block")

	// Start P2P node
	node := p2p.NewNode("0.0.0.0", 30303) // listen on all interfaces
	go node.StartServer()
	log.Println("P2P node started")

	// Start RPC server
	rpcServer := rpc.NewRPCServer(blockchain, config.TrustedRPCIP)
	go rpcServer.Start(config.RPCPort)
	log.Println("RPC server started")

	// CPU Mining loop
	if config.EnableMining {
		log.Println("Mining enabled")
		for {
			time.Sleep(time.Duration(blockchain.BlockTime) * time.Second)
			block := blockchain.MinePendingTransactions(config.AdminWallet)
			if block != nil {
				log.Printf("New block mined: %d\n", block.Index)
				// Broadcast to peers
				node.Broadcast(fmt.Sprintf("New block %d mined", block.Index))
			}
		}
	} else {
		log.Println("Mining disabled")
	}

	// Keep the main function running
	select {}
}
