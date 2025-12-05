package core

import (
	"encoding/json"
	"fmt"
	"os"
)

// Config represents the node configuration
type Config struct {
	AdminWallet  string `json:"ADMIN_WALLET"`
	RPCPort      int    `json:"RPC_PORT"`
	BlockTime    int    `json:"BLOCK_TIME"`
	EnableMining bool   `json:"ENABLE_MINING"`
	Mainnet      bool   `json:"MAINNET"`
	TrustedRPCIP string `json:"TRUSTED_RPC_IP"`
	VPNSubnet    string `json:"VPN_SUBNET"`
}

// LoadConfig loads the configuration from a JSON file
func LoadConfig(path string) (*Config, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("failed to open config file: %v", err)
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	config := &Config{}
	err = decoder.Decode(config)
	if err != nil {
		return nil, fmt.Errorf("failed to decode config JSON: %v", err)
	}

	return config, nil
}
