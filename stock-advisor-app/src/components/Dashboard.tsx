import { useMemo } from 'react'
import { buildAllocation, recommendInstruments } from '../lib/recommend'
import type { Profile } from '../types'
import { AllocationChart } from './AllocationChart'
import { Disclaimer } from './Disclaimer'
import { InstrumentList } from './InstrumentList'

const GOAL_LABEL: Record<Profile['goal'], string> = {
  retirement: 'Retirement',
  growth: 'Long-term growth',
  income: 'Income',
  'short-term': 'Short-term savings',
}

const RISK_COPY: Record<Profile['riskLevel'], string> = {
  conservative:
    'You lean toward stability. We weighted your mix toward broad, diversified funds and bonds to smooth out swings.',
  moderate:
    'You have a balanced tolerance for ups and downs. Your mix blends steady funds with a meaningful slice of individual stocks.',
  aggressive:
    'You are comfortable with volatility in exchange for higher growth potential, so your mix leans into stocks, including some higher-risk picks.',
}

interface Props {
  profile: Profile
  onRetake: () => void
}

export function Dashboard({ profile, onRetake }: Props) {
  const allocation = useMemo(() => buildAllocation(profile), [profile])
  const picks = useMemo(() => recommendInstruments(profile), [profile])

  return (
    <div className="mx-auto max-w-3xl px-4 py-10 space-y-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-slate-900 dark:text-slate-100">
            Your suggested approach
          </h1>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            Goal: <span className="font-medium">{GOAL_LABEL[profile.goal]}</span> · Horizon:{' '}
            <span className="font-medium">{profile.horizonYears}+ years</span> · Risk profile:{' '}
            <span className="font-medium capitalize">{profile.riskLevel}</span>
          </p>
        </div>
        <button
          type="button"
          onClick={onRetake}
          className="shrink-0 text-sm text-indigo-600 dark:text-indigo-400 hover:underline"
        >
          Retake quiz
        </button>
      </div>

      <section className="space-y-3">
        <h2 className="text-sm font-medium text-slate-700 dark:text-slate-300">
          Why this mix
        </h2>
        <p className="text-sm text-slate-600 dark:text-slate-400">{RISK_COPY[profile.riskLevel]}</p>
        <AllocationChart allocation={allocation} />
      </section>

      <section className="space-y-3">
        <h2 className="text-sm font-medium text-slate-700 dark:text-slate-300">
          Example instruments matching your profile
        </h2>
        <InstrumentList instruments={picks} />
      </section>

      <div className="rounded-lg border border-slate-200 dark:border-slate-700 p-4">
        <Disclaimer />
      </div>
    </div>
  )
}
