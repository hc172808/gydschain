package core

// LiquidityPool represents a token pair pool for swaps
type LiquidityPool struct {
	TokenA       string
	TokenB       string
	ReserveA     float64
	ReserveB     float64
	FeePercent   float64
	TotalShares  float64
	LiquidityMap map[string]float64 // user address → share
}

// NewLiquidityPool initializes a new liquidity pool
func NewLiquidityPool(tokenA, tokenB string, feePercent float64) *LiquidityPool {
	return &LiquidityPool{
		TokenA:       tokenA,
		TokenB:       tokenB,
		ReserveA:     0,
		ReserveB:     0,
		FeePercent:   feePercent,
		TotalShares:  0,
		LiquidityMap: make(map[string]float64),
	}
}

// AddLiquidity allows a user to add tokens to the pool and receive shares
func (lp *LiquidityPool) AddLiquidity(user string, amountA, amountB float64) float64 {
	var shares float64
	if lp.TotalShares == 0 {
		shares = amountA + amountB // initial liquidity
	} else {
		shares = ((amountA + amountB) / (lp.ReserveA + lp.ReserveB)) * lp.TotalShares
	}
	lp.ReserveA += amountA
	lp.ReserveB += amountB
	lp.TotalShares += shares
	lp.LiquidityMap[user] += shares
	return shares
}

// RemoveLiquidity allows a user to remove liquidity from the pool
func (lp *LiquidityPool) RemoveLiquidity(user string, shares float64) (float64, float64) {
	if shares > lp.LiquidityMap[user] {
		shares = lp.LiquidityMap[user]
	}
	amountA := (shares / lp.TotalShares) * lp.ReserveA
	amountB := (shares / lp.TotalShares) * lp.ReserveB
	lp.ReserveA -= amountA
	lp.ReserveB -= amountB
	lp.TotalShares -= shares
	lp.LiquidityMap[user] -= shares
	return amountA, amountB
}
