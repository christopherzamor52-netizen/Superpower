# Stock Advisor (demo)

A small client-side web app that asks about your investing goal, time horizon,
and comfort with risk, then suggests an illustrative asset allocation and a
handful of example stocks/ETFs matching that risk profile.

**This is an educational demo, not financial advice.** All market data is a
small hand-curated sample (`src/data/instruments.ts`) — there is no live
pricing and no brokerage integration. The allocation and stock-picking logic
is a simple, transparent rules engine (`src/lib/recommend.ts`), not a model
trained on real returns.

## Stack

- React + TypeScript, built with Vite
- Tailwind CSS v4 for styling
- Recharts for the allocation pie chart
- No backend — profile is kept in `localStorage`

## Running locally

```bash
npm install
npm run dev
```

Then open the printed local URL. Answer the questionnaire to see a
recommended allocation and sample instrument list; "Retake quiz" clears the
saved profile and starts over.

## How recommendations work

1. The five questionnaire answers are combined into a 1-4 risk score
   (`scoreRisk`), adjusted slightly for very short or very long time
   horizons.
2. The score maps to a `conservative` / `moderate` / `aggressive` risk level.
3. A base allocation percentage (broad-market ETFs / bond ETFs / individual
   stocks / cash) is looked up per risk level, then nudged based on the
   stated goal (e.g. "income" tilts toward bonds, "short-term" tilts toward
   cash).
4. Sample instruments are filtered to the investor's risk level and below
   (a conservative investor never sees aggressive picks), preferring sector
   variety.

## Extending this

- Swap `src/data/instruments.ts` for a real market-data API to get live
  prices/fundamentals instead of the static sample list.
- The allocation/goal rules in `src/lib/recommend.ts` are intentionally
  simple and easy to tune or replace with a more sophisticated model.
