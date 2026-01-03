package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/hc172808/gydschain/consensus/pos"
	"github.com/hc172808/gydschain/rpc"
	"github.com/hc172808/gydschain/utils"
)

func main() {
	utils.Info("Starting GYDS node")

	// Initialize PoS engine
	_ = pos.NewEngine()

	// Start RPC server (non-blocking)
	server := rpc.New(":8545")
	go func() {
		if err := server.Start(); err != nil {
			log.Fatal(err)
		}
	}()

	utils.Info("Node is running and listening")

	// ✅ Proper blocking with OS signals
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	<-sigCh
	utils.Info("Shutting down node")
}
