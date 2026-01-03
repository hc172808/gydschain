
package main

import (
    "github.com/hc172808/gydschain/consensus/pos"
    "github.com/hc172808/gydschain/rpc"
    "github.com/hc172808/gydschain/utils"
)

func main() {
    utils.Info("Starting GYDS node")

    _ = pos.NewEngine()

    server := rpc.New(":8545")
    server.Start()
}
