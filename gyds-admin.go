package main

import (
    "bytes"
    "encoding/json"
    "flag"
    "fmt"
    "io/ioutil"
    "net/http"
    "os"
)

const rpcURL = "http://127.0.0.1:8545"

type RPCRequest struct {
    Method string                 `json:"method"`
    Params map[string]interface{} `json:"params"`
    ID     int                    `json:"id"`
}

type RPCResponse struct {
    Result interface{} `json:"result,omitempty"`
    Error  string      `json:"error,omitempty"`
    ID     int         `json:"id"`
}

func sendRPC(method string, params map[string]interface{}) {
    reqBody := RPCRequest{Method: method, Params: params, ID: 1}
    data, _ := json.Marshal(reqBody)

    resp, err := http.Post(rpcURL, "application/json", bytes.NewBuffer(data))
    if err != nil {
        fmt.Println("Error:", err)
        os.Exit(1)
    }
    defer resp.Body.Close()
    body, _ := ioutil.ReadAll(resp.Body)

    var rpcResp RPCResponse
    json.Unmarshal(body, &rpcResp)

    if rpcResp.Error != "" {
        fmt.Println("RPC Error:", rpcResp.Error)
    } else {
        fmt.Println("Result:", rpcResp.Result)
    }
}

func main() {
    action := flag.String("action", "", "mint|burn|balance")
    admin := flag.String("admin", "", "Admin address")
    target := flag.String("target", "", "Target address")
    amount := flag.Int64("amount", 0, "Amount (for mint/burn)")
    flag.Parse()

    if *action == "" {
        fmt.Println("Usage: gyds-admin -action mint|burn|balance -admin <admin_addr> -target <addr> -amount <value>")
        os.Exit(1)
    }

    switch *action {
    case "mint":
        if *admin == "" || *target == "" || *amount <= 0 {
            fmt.Println("Mint requires admin, target and amount")
            os.Exit(1)
        }
        sendRPC("gyds_mint", map[string]interface{}{"admin": *admin, "to": *target, "amount": *amount})

    case "burn":
        if *admin == "" || *target == "" || *amount <= 0 {
            fmt.Println("Burn requires admin, target and amount")
            os.Exit(1)
        }
        sendRPC("gyds_burn", map[string]interface{}{"admin": *admin, "from": *target, "amount": *amount})

    case "balance":
        if *target == "" {
            fmt.Println("Balance requires target address")
            os.Exit(1)
        }
        sendRPC("gyds_balanceOf", map[string]interface{}{"address": *target})

    default:
        fmt.Println("Unknown action:", *action)
    }
}
