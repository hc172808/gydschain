package main

import (
	"log"

	"github.com/hc172808/gydschain/consensus/pos"
	"github.com/hc172808/gydschain/rpc"
	"github.com/hc172808/gydschain/utils"
)

func main() {
	utils.Info("Starting GYDS node")

	// Initialize PoS engine
	_ = pos.NewEngine()

	// Start RPC server
	server := rpc.New(":8545")
	go func() {
		if err := server.Start(); err != nil {
			log.Fatal(err)
		}
	}()

	utils.Info("Node is running and listening")

	// 🔒 BLOCK FOREVER (node stays alive)
	select {}
}
