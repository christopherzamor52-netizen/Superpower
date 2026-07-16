export interface Candle {
  time: number // unix seconds
  open: number
  high: number
  low: number
  close: number
  volume: number
}

export interface WatchlistTicker {
  symbol: string
  name: string
}

export type SignalLabel = 'buy' | 'watch' | 'wait'

export interface SignalCondition {
  key: string
  label: string
  met: boolean
}

export interface Signal {
  label: SignalLabel
  score: number
  maxScore: number
  conditions: SignalCondition[]
}

export interface Indicators {
  sma20: (number | null)[]
  sma50: (number | null)[]
  ema12: (number | null)[]
  ema26: (number | null)[]
  macdLine: (number | null)[]
  macdSignal: (number | null)[]
  macdHistogram: (number | null)[]
  rsi14: (number | null)[]
}
