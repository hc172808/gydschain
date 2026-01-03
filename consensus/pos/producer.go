package pos

import (
	"time"

	"github.com/hc172808/gydschain/core"
)

func (e *Engine) StartBlockProduction() {
	go func() {
		ticker := time.NewTicker(5 * time.Second)
		for range ticker.C {
			e.produceBlock()
		}
	}()
}

func (e *Engine) produceBlock() {
	proposer := e.State.Proposer()
	if proposer == nil || proposer.Slashed {
		return
	}

	block := core.Block{
		Height:    e.State.Height + 1,
		Timestamp: time.Now().Unix(),
		Proposer:  proposer.Address,
	}

	e.State.Height++
}
