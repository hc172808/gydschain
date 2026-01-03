package main

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/hc172808/gydschain/core"
	"github.com/hc172808/gydschain/consensus/pos"
	"github.com/hc172808/gydschain/rpc"
)

func main() {
	log.Println("[INFO] Starting GYDS node")

	genesis, err := core.LoadGenesis("genesis.json")
	if err != nil {
		log.Fatalf("[ERROR] Failed to load genesis: %v", err)
	}

	engine := pos.NewEngineFromGenesis(genesis)
	engine.StartBlockProduction()

	server := &rpc.Server{
		engine: engine,
		state:  &rpc.State{Accounts: make(map[core.Address]*core.Account)},
	}

	for addr, bal := range genesis.Balances {
		server.state.Accounts[addr] = &core.Account{
			Address: addr,
			Balance: bal,
		}
	}

	http.HandleFunc("/rpc", func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Method string          `json:"method"`
			Params json.RawMessage `json:"params"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		var res interface{}
		switch req.Method {
		case "account_get":
			var p struct{ Address core.Address }
			json.Unmarshal(req.Params, &p)
			res = server.Account(p.Address)
		case "tx_sendRaw":
			var tx core.Transaction
			json.Unmarshal(req.Params, &tx)
			if err := server.SendRawTx(tx); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			res = map[string]string{"status": "ok"}
		case "chain_getInfo":
			res = map[string]interface{}{
				"height": engine.State.Height,
				"validators": func() []string {
					var out []string
					for _, v := range engine.State.Validators {
						out = append(out, v.Address)
					}
					return out
				}(),
			}
		default:
			http.Error(w, "unknown method", http.StatusBadRequest)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(res)
	})

	addr := ":8545"
	log.Printf("[INFO] Node is running and listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
