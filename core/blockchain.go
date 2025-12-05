package core

import (
	"fmt"
	"log"
	"math"
	"time"
)

// Blockchain represents the full blockchain
type Blockchain struct {
	Blocks         []*Block
	PendingTxs     []Transaction
	Difficulty     int
	BlockTime      int // seconds per block
	LiquidityPools map[string]*LiquidityPool
	Balances       map[string]float64
}

// NewBlockchain creates a new blockchain instance
func NewBlockchain(genesisBlocks []*Block, blockTime int) *Blockchain {
	bc := &Blockchain{
		Blocks:         genesisBlocks,
		PendingTxs:     []Transaction{},
		Difficulty:     1,
		BlockTime:      blockTime,
		LiquidityPools: make(map[string]*LiquidityPool),
		Balances:       make(map[string]float64),
	}
	// Initialize balances from genesis block
	for _, tx := range genesisBlocks[0].Transactions {
		bc.Balances[tx.Recipient] = tx.Amount
	}
	return bc
}

// AddTransaction adds a transaction to pending transactions
func (bc *Blockchain) AddTransaction(tx Transaction) error {
	// Simple balance check
	if bc.Balances[tx.Sender] < tx.Amount+tx.Fee {
		return fmt.Errorf("insufficient balance")
	}
	bc.PendingTxs = append(bc.PendingTxs, tx)
	return nil
}

// MinePendingTransactions mines a new block with pending transactions
func (bc *Blockchain) MinePendingTransactions(miner string) *Block {
	if len(bc.PendingTxs) == 0 {
		log.Println("No transactions to mine")
		return nil
	}

	prevBlock := bc.Blocks[len(bc.Blocks)-1]
	newBlock := &Block{
		Index:        prevBlock.Index + 1,
		Timestamp:    time.Now().Unix(),
		PreviousHash: prevBlock.Hash,
		Transactions: bc.PendingTxs,
		Miner:        miner,
		Difficulty:   bc.Difficulty,
		Nonce:        0,
	}

	// CPU Mining: simple Proof-of-Work
	for {
		hash := newBlock.CalculateHash()
		if isValidHash(hash, newBlock.Difficulty) {
			newBlock.Hash = hash
			break
		}
		newBlock.Nonce++
	}

	// Update balances
	for _, tx := range bc.PendingTxs {
		bc.Balances[tx.Sender] -= tx.Amount + tx.Fee
		bc.Balances[tx.Recipient] += tx.Amount
		bc.Balances[miner] += tx.Fee // miner collects fees
	}

	bc.Blocks = append(bc.Blocks, newBlock)
	bc.PendingTxs = []Transaction{} // clear pending transactions

	log.Printf("Block %d mined by %s with %d transactions\n", newBlock.Index, miner, len(newBlock.Transactions))
	return newBlock
}

// Simple hash difficulty check
func isValidHash(hash string, difficulty int) bool {
	prefix := ""
	for i := 0; i < difficulty; i++ {
		prefix += "0"
	}
	return hash[:difficulty] == prefix
}

// CreateLiquidityPool adds a new pool to the blockchain
func (bc *Blockchain) CreateLiquidityPool(tokenA, tokenB string, feePercent float64) *LiquidityPool {
	key := tokenA + "_" + tokenB
	pool := NewLiquidityPool(tokenA, tokenB, feePercent)
	bc.LiquidityPools[key] = pool
	return pool
}

// GetBalance returns the balance of a wallet address
func (bc *Blockchain) GetBalance(address string) float64 {
	if val, ok := bc.Balances[address]; ok {
		return val
	}
	return 0
}

// GetLatestBlock returns the most recent block
func (bc *Blockchain) GetLatestBlock() *Block {
	return bc.Blocks[len(bc.Blocks)-1]
}

// AdjustDifficulty can be implemented to update mining difficulty dynamically
func (bc *Blockchain) AdjustDifficulty() {
	// TODO: implement dynamic difficulty based on block times
}
