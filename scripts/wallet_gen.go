package main

import (
    "crypto/rand"
    "encoding/hex"
    "fmt"
    "os"
)

func randomBytes(n int) []byte {
    b := make([]byte, n)
    rand.Read(b)
    return b
}

func main() {
    if len(os.Args) < 2 {
        fmt.Println("missing parameter: seed|priv|address")
        return
    }

    cmd := os.Args[1]

    switch cmd {

    case "seed":
        fmt.Println(hex.EncodeToString(randomBytes(32)))

    case "priv":
        fmt.Println(hex.EncodeToString(randomBytes(32)))

    case "address":
        fmt.Println("0x" + hex.EncodeToString(randomBytes(20)))

    default:
        fmt.Println("unknown command:", cmd)
    }
}

