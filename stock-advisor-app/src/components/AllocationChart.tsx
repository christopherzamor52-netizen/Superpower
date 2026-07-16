import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts'
import type { Allocation } from '../types'

const LABELS: Record<keyof Allocation, string> = {
  broadEtf: 'Broad-market ETFs',
  bondEtf: 'Bond ETFs',
  individualStocks: 'Individual stocks',
  cash: 'Cash',
}

// Colorblind-safe categorical palette, consistent across light/dark.
const COLORS: Record<keyof Allocation, string> = {
  broadEtf: '#6366f1',
  bondEtf: '#22c55e',
  individualStocks: '#f59e0b',
  cash: '#94a3b8',
}

interface Props {
  allocation: Allocation
}

export function AllocationChart({ allocation }: Props) {
  const data = (Object.keys(allocation) as (keyof Allocation)[])
    .filter((key) => allocation[key] > 0)
    .map((key) => ({
      key,
      name: LABELS[key],
      value: allocation[key],
    }))

  return (
    <div className="flex flex-col sm:flex-row items-center gap-6">
      <div className="w-56 h-56 shrink-0">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie data={data} dataKey="value" nameKey="name" innerRadius={55} outerRadius={90} paddingAngle={2}>
              {data.map((entry) => (
                <Cell key={entry.key} fill={COLORS[entry.key]} stroke="none" />
              ))}
            </Pie>
            <Tooltip formatter={(value) => `${value}%`} />
          </PieChart>
        </ResponsiveContainer>
      </div>
      <ul className="space-y-2 text-sm">
        {data.map((entry) => (
          <li key={entry.key} className="flex items-center gap-2">
            <span
              className="inline-block w-3 h-3 rounded-sm"
              style={{ backgroundColor: COLORS[entry.key] }}
            />
            <span className="text-slate-700 dark:text-slate-300">{entry.name}</span>
            <span className="font-medium text-slate-900 dark:text-slate-100">{entry.value}%</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
