package core

import (
	"encoding/json"
	"os"
	"time"
)

type Genesis struct {
	ChainID     string                        `json:"chain_id"`
	GenesisTime time.Time                     `json:"genesis_time"`
	Assets      []Asset                       `json:"assets"`
	Balances    map[Address]map[string]uint64 `json:"balances"`
	Validators  []GenesisValidator            `json:"validators"`
}

type GenesisValidator struct {
	Address Address `json:"address"`
	Stake   uint64  `json:"stake"`
}

func LoadGenesis(path string) (*Genesis, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var g Genesis
	if err := json.Unmarshal(data, &g); err != nil {
		return nil, err
	}

	return &g, nil
}
