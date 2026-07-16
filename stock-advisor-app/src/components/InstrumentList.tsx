import type { Instrument } from '../types'

const ASSET_CLASS_LABEL: Record<Instrument['assetClass'], string> = {
  stock: 'Stock',
  'bond-etf': 'Bond ETF',
  'broad-etf': 'ETF',
  cash: 'Cash',
}

const RISK_BADGE: Record<Instrument['riskLevel'], string> = {
  conservative: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950/50 dark:text-emerald-300',
  moderate: 'bg-amber-100 text-amber-800 dark:bg-amber-950/50 dark:text-amber-300',
  aggressive: 'bg-rose-100 text-rose-800 dark:bg-rose-950/50 dark:text-rose-300',
}

export function InstrumentList({ instruments }: { instruments: Instrument[] }) {
  return (
    <ul className="grid grid-cols-1 sm:grid-cols-2 gap-3">
      {instruments.map((instrument) => (
        <li
          key={instrument.ticker}
          className="rounded-lg border border-slate-200 dark:border-slate-700 p-4 space-y-2"
        >
          <div className="flex items-center justify-between">
            <span className="font-semibold text-slate-900 dark:text-slate-100">
              {instrument.ticker}
              <span className="ml-2 font-normal text-slate-500 dark:text-slate-400 text-sm">
                {instrument.name}
              </span>
            </span>
          </div>
          <div className="flex items-center gap-2 text-xs">
            <span className="rounded-full bg-slate-100 dark:bg-slate-800 px-2 py-0.5 text-slate-600 dark:text-slate-300">
              {ASSET_CLASS_LABEL[instrument.assetClass]}
            </span>
            <span className="rounded-full bg-slate-100 dark:bg-slate-800 px-2 py-0.5 text-slate-600 dark:text-slate-300">
              {instrument.sector}
            </span>
            <span className={`rounded-full px-2 py-0.5 ${RISK_BADGE[instrument.riskLevel]}`}>
              {instrument.riskLevel}
            </span>
          </div>
          <p className="text-sm text-slate-600 dark:text-slate-400">{instrument.blurb}</p>
        </li>
      ))}
    </ul>
  )
}
