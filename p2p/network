package p2p

import (
	"fmt"
	"log"
	"net"
)

// Node represents a P2P node
type Node struct {
	IP      string
	Port    int
	Peers   map[string]*Peer
}

// Peer represents a connected peer node
type Peer struct {
	IP   string
	Port int
	Conn net.Conn
}

// NewNode creates a new P2P node
func NewNode(ip string, port int) *Node {
	return &Node{
		IP:    ip,
		Port:  port,
		Peers: make(map[string]*Peer),
	}
}

// StartServer listens for incoming peer connections
func (n *Node) StartServer() {
	address := fmt.Sprintf("%s:%d", n.IP, n.Port)
	listener, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("Failed to start P2P server: %v", err)
	}
	log.Printf("P2P node listening on %s\n", address)

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Println("Failed to accept peer connection:", err)
			continue
		}
		go n.handleConnection(conn)
	}
}

// ConnectToPeer establishes a connection to another peer
func (n *Node) ConnectToPeer(ip string, port int) {
	address := fmt.Sprintf("%s:%d", ip, port)
	conn, err := net.Dial("tcp", address)
	if err != nil {
		log.Printf("Failed to connect to peer %s: %v", address, err)
		return
	}
	peer := &Peer{
		IP:   ip,
		Port: port,
		Conn: conn,
	}
	n.Peers[address] = peer
	log.Printf("Connected to peer %s\n", address)
}

// handleConnection handles incoming messages from a peer
func (n *Node) handleConnection(conn net.Conn) {
	defer conn.Close()
	peerAddr := conn.RemoteAddr().String()
	log.Printf("New peer connected: %s\n", peerAddr)

	buf := make([]byte, 1024)
	for {
		nBytes, err := conn.Read(buf)
		if err != nil {
			log.Printf("Peer disconnected: %s\n", peerAddr)
			delete(n.Peers, peerAddr)
			return
		}
		message := string(buf[:nBytes])
		log.Printf("Received from %s: %s\n", peerAddr, message)
		// TODO: handle block/transaction messages
	}
}

// Broadcast sends a message to all connected peers
func (n *Node) Broadcast(message string) {
	for addr, peer := range n.Peers {
		_, err := peer.Conn.Write([]byte(message))
		if err != nil {
			log.Printf("Failed to send to %s: %v", addr, err)
		}
	}
}
