package rpc

import "github.com/hc172808/gydschain/core"

func (s *Server) SendRawTx(tx core.Transaction) error {
	acc := s.state.Account(tx.From)

	if tx.Nonce != acc.Nonce {
		return &core.ErrString{"bad nonce"}
	}

	acc.Nonce++

	switch tx.Type {
	case core.TxStake:
		return s.engine.ApplyStake(tx, acc)
	case core.TxUnstake:
		return s.engine.ApplyUnstake(tx, acc)
	default:
		return nil
	}
}
