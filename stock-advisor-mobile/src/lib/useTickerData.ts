import { useEffect, useState } from 'react'
import type { Candle, Indicators, Signal } from '../types'
import { computeIndicators } from './indicators'
import { computeSignal } from './signal'
import { fetchChart } from './yahooFinance'

interface TickerData {
  status: 'loading' | 'error' | 'ready'
  candles: Candle[]
  indicators: Indicators | null
  signal: Signal | null
  error: string | null
}

const LOADING: TickerData = { status: 'loading', candles: [], indicators: null, signal: null, error: null }

export function useTickerData(symbol: string): TickerData {
  const [state, setState] = useState<TickerData>(LOADING)

  useEffect(() => {
    let cancelled = false
    setState(LOADING)

    fetchChart(symbol)
      .then((candles) => {
        if (cancelled) return
        if (candles.length < 50) {
          setState({
            status: 'error',
            candles: [],
            indicators: null,
            signal: null,
            error: 'Not enough price history for this symbol yet.',
          })
          return
        }
        setState({
          status: 'ready',
          candles,
          indicators: computeIndicators(candles),
          signal: computeSignal(candles),
          error: null,
        })
      })
      .catch((err: unknown) => {
        if (cancelled) return
        setState({
          status: 'error',
          candles: [],
          indicators: null,
          signal: null,
          error: err instanceof Error ? err.message : 'Failed to load chart data.',
        })
      })

    return () => {
      cancelled = true
    }
  }, [symbol])

  return state
}
