func (s *Server) SendRawTx(tx core.Transaction) error {
	acc := s.state.Account(tx.From)

	if tx.Nonce != acc.Nonce {
		return ErrBadNonce
	}

	acc.Nonce++
	return core.ApplyTx(tx, acc, s.engine)
}
