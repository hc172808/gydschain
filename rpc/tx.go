package rpc

import (
	"github.com/hc172808/gydschain/core"
	"github.com/hc172808/gydschain/consensus/pos"
)

type Server struct {
	engine *pos.Engine
	state  *State
}

type State struct {
	Accounts map[core.Address]*core.Account
}

func (s *Server) Account(addr core.Address) *core.Account {
	acc, ok := s.state.Accounts[addr]
	if !ok {
		acc = &core.Account{
			Address: addr,
			Balance: map[string]uint64{"GYDS": 0},
		}
		s.state.Accounts[addr] = acc
	}
	return acc
}

func (s *Server) SendRawTx(tx core.Transaction) error {
	acc := s.Account(tx.From)
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
