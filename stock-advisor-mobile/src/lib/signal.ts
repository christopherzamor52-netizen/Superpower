import { computeIndicators } from './indicators'
import type { Candle, Signal, SignalCondition } from '../types'

function lastNonNull(values: (number | null)[], endIndex: number): number | null {
  for (let i = endIndex; i >= 0; i--) {
    if (values[i] !== null) return values[i]
  }
  return null
}

// Detects whether `a` crossed above `b` within the last `lookback` bars
// (a was <= b, then a > b).
function crossedAboveRecently(
  a: (number | null)[],
  b: (number | null)[],
  atIndex: number,
  lookback: number,
): boolean {
  for (let i = Math.max(1, atIndex - lookback + 1); i <= atIndex; i++) {
    const aNow = a[i]
    const bNow = b[i]
    const aPrev = a[i - 1]
    const bPrev = b[i - 1]
    if (aNow === null || bNow === null || aPrev === null || bPrev === null) continue
    if (aPrev <= bPrev && aNow > bNow) return true
  }
  return false
}

export function computeSignal(candles: Candle[]): Signal {
  const indicators = computeIndicators(candles)
  const lastIndex = candles.length - 1
  const closes = candles.map((c) => c.close)
  const lastClose = closes[lastIndex]

  const sma20 = lastNonNull(indicators.sma20, lastIndex)
  const sma50 = lastNonNull(indicators.sma50, lastIndex)
  const rsiNow = lastNonNull(indicators.rsi14, lastIndex)

  const goldenCross = crossedAboveRecently(indicators.sma20, indicators.sma50, lastIndex, 10)
  const macdCrossUp = crossedAboveRecently(indicators.macdLine, indicators.macdSignal, lastIndex, 5)
  const priceAboveSma50 = sma50 !== null && lastClose > sma50

  const rsiRecoveredFromOversold = (() => {
    const window = indicators.rsi14.slice(Math.max(0, lastIndex - 10), lastIndex + 1)
    const wasOversold = window.some((v) => v !== null && v < 30)
    return wasOversold && rsiNow !== null && rsiNow >= 30
  })()

  const rsiOverbought = rsiNow !== null && rsiNow > 70

  const conditions: SignalCondition[] = [
    { key: 'goldenCross', label: '20-day average crossed above the 50-day average', met: goldenCross },
    { key: 'macdCrossUp', label: 'MACD line crossed above its signal line', met: macdCrossUp },
    { key: 'priceAboveSma50', label: 'Price is trading above its 50-day average', met: priceAboveSma50 },
    { key: 'rsiRecovered', label: 'RSI recovered out of oversold territory (<30)', met: rsiRecoveredFromOversold },
  ]

  const score = conditions.filter((c) => c.met).length
  const maxScore = conditions.length

  let label: Signal['label'] = 'wait'
  if (rsiOverbought) {
    label = 'wait'
  } else if (score >= 3) {
    label = 'buy'
  } else if (score >= 1) {
    label = 'watch'
  }

  if (rsiOverbought) {
    conditions.push({ key: 'rsiOverbought', label: 'RSI is above 70 (overbought)', met: true })
  }

  return { label, score, maxScore, conditions }
}
