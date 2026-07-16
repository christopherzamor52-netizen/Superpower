import type { Candle, Indicators } from '../types'

export function sma(values: number[], period: number): (number | null)[] {
  const result: (number | null)[] = new Array(values.length).fill(null)
  let sum = 0
  for (let i = 0; i < values.length; i++) {
    sum += values[i]
    if (i >= period) sum -= values[i - period]
    if (i >= period - 1) result[i] = sum / period
  }
  return result
}

export function ema(values: number[], period: number): (number | null)[] {
  const result: (number | null)[] = new Array(values.length).fill(null)
  const k = 2 / (period + 1)
  let prev: number | null = null
  for (let i = 0; i < values.length; i++) {
    if (i === period - 1) {
      const seed = values.slice(0, period).reduce((a, b) => a + b, 0) / period
      prev = seed
      result[i] = seed
    } else if (i >= period && prev !== null) {
      const next: number = values[i] * k + prev * (1 - k)
      result[i] = next
      prev = next
    }
  }
  return result
}

export function rsi(values: number[], period = 14): (number | null)[] {
  const result: (number | null)[] = new Array(values.length).fill(null)
  if (values.length <= period) return result

  let gainSum = 0
  let lossSum = 0
  for (let i = 1; i <= period; i++) {
    const change = values[i] - values[i - 1]
    if (change > 0) gainSum += change
    else lossSum -= change
  }
  let avgGain = gainSum / period
  let avgLoss = lossSum / period
  result[period] = rsiFromAverages(avgGain, avgLoss)

  for (let i = period + 1; i < values.length; i++) {
    const change = values[i] - values[i - 1]
    const gain = change > 0 ? change : 0
    const loss = change < 0 ? -change : 0
    avgGain = (avgGain * (period - 1) + gain) / period
    avgLoss = (avgLoss * (period - 1) + loss) / period
    result[i] = rsiFromAverages(avgGain, avgLoss)
  }

  return result
}

function rsiFromAverages(avgGain: number, avgLoss: number): number {
  if (avgLoss === 0) return 100
  const rs = avgGain / avgLoss
  return 100 - 100 / (1 + rs)
}

export function macd(
  values: number[],
  fast = 12,
  slow = 26,
  signalPeriod = 9,
): { macdLine: (number | null)[]; signalLine: (number | null)[]; histogram: (number | null)[] } {
  const emaFast = ema(values, fast)
  const emaSlow = ema(values, slow)
  const macdLine: (number | null)[] = values.map((_, i) => {
    const f = emaFast[i]
    const s = emaSlow[i]
    return f !== null && s !== null ? f - s : null
  })

  // Signal line is the EMA of the MACD line, computed only over the
  // contiguous run of non-null values (starts once both EMAs exist).
  const firstValid = macdLine.findIndex((v) => v !== null)
  const signalLine: (number | null)[] = new Array(values.length).fill(null)
  if (firstValid !== -1) {
    const macdValues = macdLine.slice(firstValid) as number[]
    const emaOfMacd = ema(macdValues, signalPeriod)
    for (let i = 0; i < emaOfMacd.length; i++) {
      signalLine[firstValid + i] = emaOfMacd[i]
    }
  }

  const histogram: (number | null)[] = values.map((_, i) => {
    const m = macdLine[i]
    const s = signalLine[i]
    return m !== null && s !== null ? m - s : null
  })

  return { macdLine, signalLine, histogram }
}

export function computeIndicators(candles: Candle[]): Indicators {
  const closes = candles.map((c) => c.close)
  const { macdLine, signalLine, histogram } = macd(closes)
  return {
    sma20: sma(closes, 20),
    sma50: sma(closes, 50),
    ema12: ema(closes, 12),
    ema26: ema(closes, 26),
    macdLine,
    macdSignal: signalLine,
    macdHistogram: histogram,
    rsi14: rsi(closes, 14),
  }
}
