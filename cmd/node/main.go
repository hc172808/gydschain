package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/hc172808/gydschain/consensus/pos"
	"github.com/hc172808/gydschain/core"
	"github.com/hc172808/gydschain/rpc"
	"github.com/hc172808/gydschain/utils"
)

func main() {
	utils.Info("Starting GYDS node")

	genesis, err := core.LoadGenesis("config/genesis.json")
	if err != nil {
		log.Fatal(err)
	}

	engine := pos.NewEngineFromGenesis(genesis)
	engine.StartBlockProduction()

	server := rpc.New(":8545")
	go server.Start()

	utils.Info("Node running with PoS consensus")

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
}
