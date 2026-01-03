package rpc

type Server struct {
    Addr string
}

func New(addr string) *Server {
    return &Server{Addr: addr}
}

func (s *Server) Start() error {
    return nil
}
