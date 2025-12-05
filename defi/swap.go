package defi

import (
	"fmt"
	"math"

	"gyds-chain/core"
)

// Swap performs a token swap in a liquidity pool
func Swap(pool *core.LiquidityPool, fromToken string, amountIn float64) (float64, error) {
	if amountIn <= 0 {
		return 0, fmt.Errorf("invalid swap amount")
	}

	var reserveIn, reserveOut float64
	if fromToken == pool.TokenA {
		reserveIn = pool.ReserveA
		reserveOut = pool.ReserveB
	} else if fromToken == pool.TokenB {
		reserveIn = pool.ReserveB
		reserveOut = pool.ReserveA
	} else {
		return 0, fmt.Errorf("token not in pool")
	}

	if reserveIn <= 0 || reserveOut <= 0 {
		return 0, fmt.Errorf("insufficient liquidity in pool")
	}

	// Apply fee
	amountInWithFee := amountIn * (1 - pool.FeePercent/100)

	// Constant product formula: x * y = k
	amountOut := (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee)

	// Update pool reserves
	if fromToken == pool.TokenA {
		pool.ReserveA += amountIn
		pool.ReserveB -= amountOut
	} else {
		pool.ReserveB += amountIn
		pool.ReserveA -= amountOut
	}

	return math.Round(amountOut*1e8) / 1e8, nil // round to 8 decimals
}

// GetPrice returns the current price of fromToken in terms of toToken
func GetPrice(pool *core.LiquidityPool, fromToken string) (float64, error) {
	if fromToken == pool.TokenA {
		if pool.ReserveA == 0 {
			return 0, fmt.Errorf("reserve is zero")
		}
		return pool.ReserveB / pool.ReserveA, nil
	} else if fromToken == pool.TokenB {
		if pool.ReserveB == 0 {
			return 0, fmt.Errorf("reserve is zero")
		}
		return pool.ReserveA / pool.ReserveB, nil
	} else {
		return 0, fmt.Errorf("token not in pool")
	}
}
