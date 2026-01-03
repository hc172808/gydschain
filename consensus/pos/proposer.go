package pos

func (s *State) Proposer() *Validator {
	if len(s.Validators) == 0 {
		return nil
	}
	index := int(s.Height % uint64(len(s.Validators)))
	return s.Validators[index]
}
