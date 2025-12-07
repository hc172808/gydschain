package p2p

import (
	"bufio"
	"fmt"
	"log"
	"net"
)

type Node struct {
	Host string
	Port int
}

func NewNode(host string, port int) *Node {
	return &Node{Host: host, Port: port}
}

// StartServer listens for incoming connections
func (n *Node) StartServer() {
	address := fmt.Sprintf("%s:%d", n.Host, n.Port)
	listener, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("Failed to start P2P server: %v", err)
	}
	log.Printf("🌐 P2P node listening on %s", address)

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Println("Failed to accept connection:", err)
			continue
		}
		go n.handleConnection(conn)
	}
}

func (n *Node) handleConnection(conn net.Conn) {
	defer conn.Close()
	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		message := scanner.Text()
		log.Printf("📨 Received: %s", message)
	}
	if err := scanner.Err(); err != nil {
		log.Println("Connection error:", err)
	}
}

// Broadcast message to peers (stub for now)
func (n *Node) Broadcast(message string) {
	log.Printf("📡 Broadcast: %s", message)
	// You can extend this to send messages to connected peers
}
