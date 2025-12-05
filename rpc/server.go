package rpc

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"

	"gyds-chain/core"
	"gyds-chain/defi"
)

// RPCServer holds the blockchain reference and trusted IP
type RPCServer struct {
	Blockchain    *core.Blockchain
	TrustedRPCIP  string
	LiquidityPools map[string]*core.LiquidityPool
}

// NewRPCServer creates a new RPC server instance
func NewRPCServer(bc *core.Blockchain, trustedIP string) *RPCServer {
	return &RPCServer{
		Blockchain:    bc,
		TrustedRPCIP:  trustedIP,
		LiquidityPools: bc.LiquidityPools,
	}
}

// Start runs the HTTP server for RPC endpoints
func (s *RPCServer) Start(port int) {
	http.HandleFunc("/getChain", s.handleGetChain)
	http.HandleFunc("/getBalances", s.handleGetBalances)
	http.HandleFunc("/swap", s.handleSwap)
	http.HandleFunc("/tokenMetadata", s.handleTokenMetadata)
	http.HandleFunc("/createWallet", s.handleCreateWallet)

	address := fmt.Sprintf(":%d", port)
	log.Printf("RPC server listening on %s\n", address)
	if err := http.ListenAndServe(address, nil); err != nil {
		log.Fatalf("Failed to start RPC server: %v", err)
	}
}

// --- Handlers ---

func (s *RPCServer) handleGetChain(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(s.Blockchain.Blocks)
}

func (s *RPCServer) handleGetBalances(w http.ResponseWriter, r *http.Request) {
	addr := r.URL.Query().Get("address")
	if addr == "" {
		http.Error(w, "address query param required", http.StatusBadRequest)
		return
	}
	balance := s.Blockchain.GetBalance(addr)
	json.NewEncoder(w).Encode(map[string]float64{"balance": balance})
}

func (s *RPCServer) handleSwap(w http.ResponseWriter, r *http.Request) {
	fromToken := r.URL.Query().Get("from")
	toToken := r.URL.Query().Get("to")
	amountStr := r.URL.Query().Get("amount")

	if fromToken == "" || toToken == "" || amountStr == "" {
		http.Error(w, "from, to, and amount required", http.StatusBadRequest)
		return
	}

	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil {
		http.Error(w, "invalid amount", http.StatusBadRequest)
		return
	}

	poolKey := fromToken + "_" + toToken
	pool, exists := s.LiquidityPools[poolKey]
	if !exists {
		poolKey = toToken + "_" + fromToken
		pool, exists = s.LiquidityPools[poolKey]
		if !exists {
			http.Error(w, "liquidity pool not found", http.StatusNotFound)
			return
		}
	}

	out, err := defi.Swap(pool, fromToken, amount)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	json.NewEncoder(w).Encode(map[string]float64{"amount_out": out})
}

func (s *RPCServer) handleTokenMetadata(w http.ResponseWriter, r *http.Request) {
	// Placeholder: in production, fetch token metadata from blockchain/token engine
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "token query param required", http.StatusBadRequest)
		return
	}

	metadata := map[string]interface{}{
		"symbol":    token,
		"name":      token,
		"decimals":  8,
		"totalSupply": 10
