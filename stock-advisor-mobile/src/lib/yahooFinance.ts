import type { Candle } from '../types'

export interface YahooChartResponse {
  chart: {
    result: Array<{
      meta: { regularMarketPrice?: number; currency?: string; shortName?: string }
      timestamp?: number[]
      indicators: {
        quote: Array<{
          open: Array<number | null>
          high: Array<number | null>
          low: Array<number | null>
          close: Array<number | null>
          volume: Array<number | null>
        }>
      }
    }> | null
    error: { code: string; description: string } | null
  }
}

export class TickerNotFoundError extends Error {}

// Parses Yahoo's public (unofficial) chart response into clean candles,
// dropping any bar with a missing field (holidays/halts sometimes leave nulls).
export function parseYahooChart(json: YahooChartResponse): Candle[] {
  if (json.chart.error) {
    throw new TickerNotFoundError(json.chart.error.description || 'Unknown ticker')
  }
  const result = json.chart.result?.[0]
  if (!result || !result.timestamp) {
    throw new TickerNotFoundError('No chart data returned for this symbol')
  }

  const quote = result.indicators.quote[0]
  const candles: Candle[] = []

  for (let i = 0; i < result.timestamp.length; i++) {
    const open = quote.open[i]
    const high = quote.high[i]
    const low = quote.low[i]
    const close = quote.close[i]
    const volume = quote.volume[i]
    if (open === null || high === null || low === null || close === null) continue

    candles.push({
      time: result.timestamp[i],
      open,
      high,
      low,
      close,
      volume: volume ?? 0,
    })
  }

  return candles
}

const CHART_BASE_URL = 'https://query1.finance.yahoo.com/v8/finance/chart'

// Yahoo's public chart endpoint is unofficial and undocumented, but widely
// used for exactly this purpose: no API key, works for any valid ticker.
export async function fetchChart(symbol: string, range = '6mo', interval = '1d'): Promise<Candle[]> {
  const url = `${CHART_BASE_URL}/${encodeURIComponent(symbol)}?range=${range}&interval=${interval}`
  const response = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; StockAdvisorMobile/1.0)' },
  })

  if (!response.ok) {
    throw new Error(`Chart request failed with status ${response.status}`)
  }

  const json = (await response.json()) as YahooChartResponse
  return parseYahooChart(json)
}
