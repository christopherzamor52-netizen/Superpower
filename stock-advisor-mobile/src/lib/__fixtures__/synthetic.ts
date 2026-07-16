import type { Candle } from '../../types'

// Deterministic synthetic OHLC series for local testing without network
// access: a downtrend into an oversold dip, then a recovering uptrend,
// which should trip several of the bullish signal conditions near the end.
export function makeSyntheticCandles(days = 120): Candle[] {
  const candles: Candle[] = []
  let price = 150
  const startTime = Math.floor(Date.now() / 1000) - days * 86400

  for (let i = 0; i < days; i++) {
    const phase = i / days
    let drift: number
    if (phase < 0.4) drift = -0.6 // downtrend
    else if (phase < 0.55) drift = -0.1 // basing / oversold dip
    else drift = 0.9 // recovery uptrend

    const noise = Math.sin(i * 1.3) * 0.8
    price = Math.max(5, price + drift + noise)

    const open = price - 0.3
    const close = price
    const high = Math.max(open, close) + 0.5
    const low = Math.min(open, close) - 0.5

    candles.push({
      time: startTime + i * 86400,
      open,
      high,
      low,
      close,
      volume: 1_000_000 + Math.round(Math.random() * 200_000),
    })
  }

  return candles
}
