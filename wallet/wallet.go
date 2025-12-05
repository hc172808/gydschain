package wallet

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/rand"
	"time"
)

// Wallet represents a simple HD wallet
type Wallet struct {
	Seed       string
	PrivateKey string
	PublicKey  string
	Address    string
}

// NewWallet generates a new wallet with a random seed phrase
func NewWallet() *Wallet {
	seed := generateSeedPhrase()
	privateKey := generatePrivateKey(seed)
	publicKey := generatePublicKey(privateKey)
	address := generateAddress(publicKey)

	return &Wallet{
		Seed:       seed,
		PrivateKey: privateKey,
		PublicKey:  publicKey,
		Address:    address,
	}
}

// generateSeedPhrase creates a simple random seed phrase (12 words)
func generateSeedPhrase() string {
	words := []string{
		"apple", "banana", "cherry", "date", "elderberry", "fig", "grape",
		"honeydew", "kiwi", "lemon", "mango", "nectarine",
	}
	rand.Seed(time.Now().UnixNano())
	seed := ""
	for i := 0; i < 12; i++ {
		seed += words[rand.Intn(len(words))] + " "
	}
	return seed[:len(seed)-1] // remove trailing space
}

// generatePrivateKey derives a private key from the seed
func generatePrivateKey(seed string) string {
	hash := sha256.Sum256([]byte(seed))
	return hex.EncodeToString(hash[:])
}

// generatePublicKey derives a public key from the private key (placeholder)
func generatePublicKey(privateKey string) string {
	hash := sha256.Sum256([]byte(privateKey))
	return hex.EncodeToString(hash[:])
}

// generateAddress generates a wallet address from the public key (placeholder)
func generateAddress(publicKey string) string {
	hash := sha256.Sum256([]byte(publicKey))
	return "GYDS_" + hex.EncodeToString(hash[:8]) // first 8 bytes for simplicity
}

// Display prints wallet info
func (w *Wallet) Display() {
	fmt.Println("Address:", w.Address)
	fmt.Println("PublicKey:", w.PublicKey)
	fmt.Println("PrivateKey:", w.PrivateKey)
	fmt.Println("Seed Phrase:", w.Seed)
}
