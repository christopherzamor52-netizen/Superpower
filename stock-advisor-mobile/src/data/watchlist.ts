import type { WatchlistTicker } from '../types'

// Default suggestions across sectors. Users can add any valid ticker symbol
// via search — this list is just a starting point, not a limit.
export const DEFAULT_WATCHLIST: WatchlistTicker[] = [
  { symbol: 'AAPL', name: 'Apple Inc.' },
  { symbol: 'MSFT', name: 'Microsoft Corp.' },
  { symbol: 'NVDA', name: 'NVIDIA Corp.' },
  { symbol: 'AMZN', name: 'Amazon.com Inc.' },
  { symbol: 'GOOGL', name: 'Alphabet Inc.' },
  { symbol: 'TSLA', name: 'Tesla Inc.' },
  { symbol: 'JNJ', name: 'Johnson & Johnson' },
  { symbol: 'JPM', name: 'JPMorgan Chase & Co.' },
  { symbol: 'KO', name: 'Coca-Cola Co.' },
  { symbol: 'XOM', name: 'Exxon Mobil Corp.' },
  { symbol: 'VOO', name: 'Vanguard S&P 500 ETF' },
  { symbol: 'QQQ', name: 'Invesco QQQ Trust' },
]
