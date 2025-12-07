package main

import (
    "crypto/ecdsa"
    "crypto/elliptic"
    "crypto/rand"
    "crypto/sha256"
    "encoding/hex"
    "flag"
    "fmt"
    "log"

    bip39 "github.com/tyler-smith/go-bip39"
)

func main() {
    createFlag := flag.Bool("create", false, "Create new wallet")
    recoverFlag := flag.String("recover", "", "Recover wallet from mnemonic")
    flag.Parse()

    if *createFlag {
        createWallet()
    } else if *recoverFlag != "" {
        fmt.Println("Recover from mnemonic:", *recoverFlag)
        // implement recover function if needed
    } else {
        flag.Usage()
    }
}

func createWallet() {
    entropy, err := bip39.NewEntropy(256)
    if err != nil {
        log.Fatal(err)
    }

    mnemonic, err := bip39.NewMnemonic(entropy)
    if err != nil {
        log.Fatal(err)
    }

    seed := bip39.NewSeed(mnemonic, "")

    priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
    if err != nil {
        log.Fatal(err)
    }

    privKeyHex := hex.EncodeToString(priv.D.Bytes())

    pubKey := append(priv.PublicKey.X.Bytes(), priv.PublicKey.Y.Bytes()...)
    pubHash := sha256.Sum256(pubKey)
    address := hex.EncodeToString(pubHash[:])

    fmt.Println("=====================================")
    fmt.Println(" GYDS Wallet Generated")
    fmt.Println("=====================================")
    fmt.Println("Seed Phrase:", mnemonic)
    fmt.Println("Private Key:", privKeyHex)
    fmt.Println("Public Address:", address)
    fmt.Println("=====================================")
}
