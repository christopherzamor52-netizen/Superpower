# Stock Advisor Mobile (demo)

A cross-platform mobile app (iOS/Android/web, via Expo) that pulls a real
price chart for any stock ticker and shows a transparent, rule-based
technical-analysis signal for it — a watchlist with "BUY SIGNAL / WATCH /
WAIT" badges, and a detail screen with the price chart, RSI, MACD, and a
checklist explaining exactly why the signal is what it is.

**This is an educational demo, not financial advice, and not a trading
bot.** It does not place trades, does not use real-time streaming data, and
the "signal" is nothing more than a few classic technical-analysis rules
(moving-average crossovers, RSI, MACD) applied to daily closing prices —
the same kind of heuristic covered in any intro technical-analysis
article, not a predictive model. See `src/lib/signal.ts` for the exact,
fully transparent logic — there is no hidden scoring.

## Stack

- Expo + React Native + TypeScript
- `react-native-svg` for hand-rolled charts (price/SMA overlay, RSI, MACD) —
  no heavyweight charting library needed
- No backend, no auth, no persistence beyond in-memory state

## Data source

Charts are fetched live from Yahoo Finance's public chart endpoint
(`query1.finance.yahoo.com/v8/finance/chart/<SYMBOL>`). This is an
**unofficial, undocumented** endpoint — no API key required, works for
effectively any valid ticker, but it can change or rate-limit without
notice. `src/lib/yahooFinance.ts` isolates all of this behind
`fetchChart(symbol)`, so swapping in a real provider (Alpha Vantage,
Finnhub, Polygon, IEX, etc.) later just means rewriting that one file.

> Note on how this was verified: the sandbox this app was built in has no
> outbound network access to Yahoo Finance (or most of the open internet),
> so the live fetch could not be exercised end-to-end here. Everything
> downstream of the network call — JSON parsing (`parseYahooChart`),
> indicator math, the signal engine, and the full UI — was verified against
> a realistic fixture shaped like Yahoo's actual response. Test this on a
> real device/simulator with normal internet access before relying on it.

## Running locally

```bash
npm install
npm run web    # fastest way to preview (uses react-native-web)
# or
npm run ios    # requires macOS + Xcode
npm run android
```

## How it works

1. **Watchlist screen** (`src/screens/WatchlistScreen.tsx`) — a curated
   starter list of ~12 large/liquid tickers, plus a text field to add any
   other symbol. Each row independently fetches its own chart and shows
   last price, day change, and a signal badge.
2. **Indicators** (`src/lib/indicators.ts`) — SMA(20), SMA(50), EMA(12/26),
   MACD(12,26,9), and RSI(14), computed from daily closes with plain,
   dependency-free math.
3. **Signal** (`src/lib/signal.ts`) — checks four conditions: a recent
   20/50-day golden cross, a recent MACD bullish crossover, price above its
   50-day average, and RSI recovering out of oversold. 3+ conditions →
   "BUY SIGNAL", 1-2 → "WATCH", 0 (or RSI overbought) → "WAIT". The detail
   screen always shows this checklist, not just the final label.
4. **Detail screen** (`src/screens/StockDetailScreen.tsx`) — price chart
   with moving averages, RSI chart with 30/70 reference lines, MACD
   histogram, and the signal checklist, all built on `react-native-svg`.

## Limitations / next steps

- "Every stock" in practice means "any ticker Yahoo's endpoint recognizes"
  — there's no local database of symbols, so typos just show an error.
- No caching/rate-limit handling; a long watchlist means one network
  request per row, per app open.
- The signal rules are intentionally simple and easy to read/tune in
  `src/lib/signal.ts` — this is a starting point, not a tuned strategy.
