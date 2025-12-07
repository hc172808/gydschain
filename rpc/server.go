package rpc

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"gyds-chain/core"
)

type RPCServer struct {
	Blockchain   *core.Blockchain
	TrustedIP    string
}

func NewRPCServer(bc *core.Blockchain, trustedIP string) *RPCServer {
	return &RPCServer{
		Blockchain: bc,
		TrustedIP:  trustedIP,
	}
}

func (r *RPCServer) Start(port int) {
	http.HandleFunc("/getChain", r.getChain)
	address := fmt.Sprintf(":%d", port)
	log.Printf("🖥 RPC server listening on %s", address)
	if err := http.ListenAndServe(address, nil); err != nil {
		log.Fatalf("RPC server failed: %v", err)
	}
}

func (r *RPCServer) getChain(w http.ResponseWriter, req *http.Request) {
	if req.RemoteAddr[:len(r.TrustedIP)] != r.TrustedIP {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	data := map[string]interface{}{
		"length": len(r.Blockchain.Blocks),
		"chain":  r.Blockchain.Blocks,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
