package core

import "github.com/hc172808/gydschain/consensus/pos"

func ApplyTx(tx Transaction, acc *Account, engine *pos.Engine) error {
	switch tx.Type {
	case TxStake:
		return engine.ApplyStake(tx, acc)
	case TxUnstake:
		return engine.ApplyUnstake(tx, acc)
	default:
		return nil
	}
}
