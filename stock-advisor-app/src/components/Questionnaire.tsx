import { useState } from 'react'
import type { Goal, QuizAnswers } from '../types'

interface Props {
  onComplete: (answers: QuizAnswers) => void
}

const GOAL_OPTIONS: { value: Goal; label: string; hint: string }[] = [
  { value: 'retirement', label: 'Retirement', hint: 'Investing steadily for decades out' },
  { value: 'growth', label: 'Long-term growth', hint: 'Building wealth over 5+ years' },
  { value: 'income', label: 'Income', hint: 'Generating regular dividends/interest' },
  { value: 'short-term', label: 'Short-term savings', hint: 'A goal within the next 1-3 years' },
]

const HORIZON_OPTIONS = [
  { value: 1, label: 'Less than 2 years' },
  { value: 4, label: '2-5 years' },
  { value: 10, label: '5-15 years' },
  { value: 20, label: 'More than 15 years' },
]

const SCALE_OPTIONS = [
  { value: 1, label: 'Strongly disagree' },
  { value: 2, label: 'Disagree' },
  { value: 3, label: 'Agree' },
  { value: 4, label: 'Strongly agree' },
]

export function Questionnaire({ onComplete }: Props) {
  const [goal, setGoal] = useState<Goal | null>(null)
  const [horizonYears, setHorizonYears] = useState<number | null>(null)
  const [reactionToDrop, setReactionToDrop] = useState<number | null>(null)
  const [incomeStability, setIncomeStability] = useState<number | null>(null)
  const [experience, setExperience] = useState<number | null>(null)

  const canSubmit =
    goal !== null &&
    horizonYears !== null &&
    reactionToDrop !== null &&
    incomeStability !== null &&
    experience !== null

  function handleSubmit() {
    if (!canSubmit) return
    onComplete({
      goal,
      horizonYears,
      reactionToDrop,
      incomeStability,
      experience,
    })
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-10 space-y-10">
      <div>
        <h1 className="text-2xl font-semibold text-slate-900 dark:text-slate-100">
          Tell us about your investing goals
        </h1>
        <p className="mt-2 text-sm text-slate-500 dark:text-slate-400">
          A few questions so we can tailor suggestions to your goal and comfort with risk.
        </p>
      </div>

      <Section title="What's your main goal?">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {GOAL_OPTIONS.map((opt) => (
            <OptionCard
              key={opt.value}
              selected={goal === opt.value}
              onClick={() => setGoal(opt.value)}
            >
              <div className="font-medium">{opt.label}</div>
              <div className="text-xs opacity-70">{opt.hint}</div>
            </OptionCard>
          ))}
        </div>
      </Section>

      <Section title="When do you expect to need this money?">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {HORIZON_OPTIONS.map((opt) => (
            <OptionCard
              key={opt.value}
              selected={horizonYears === opt.value}
              onClick={() => setHorizonYears(opt.value)}
            >
              {opt.label}
            </OptionCard>
          ))}
        </div>
      </Section>

      <Section title="If my investments dropped 20% in a month, I would stay the course or buy more.">
        <ScaleRow value={reactionToDrop} onChange={setReactionToDrop} />
      </Section>

      <Section title="My income and expenses are stable and predictable.">
        <ScaleRow value={incomeStability} onChange={setIncomeStability} />
      </Section>

      <Section title="I'm comfortable evaluating individual companies, not just funds.">
        <ScaleRow value={experience} onChange={setExperience} />
      </Section>

      <button
        type="button"
        disabled={!canSubmit}
        onClick={handleSubmit}
        className="w-full rounded-lg bg-indigo-600 px-4 py-3 text-white font-medium
          disabled:opacity-40 disabled:cursor-not-allowed
          enabled:hover:bg-indigo-700 transition-colors"
      >
        See my recommendations
      </button>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="space-y-3">
      <h2 className="text-sm font-medium text-slate-700 dark:text-slate-300">{title}</h2>
      {children}
    </div>
  )
}

function OptionCard({
  selected,
  onClick,
  children,
}: {
  selected: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`text-left rounded-lg border px-4 py-3 transition-colors ${
        selected
          ? 'border-indigo-500 bg-indigo-50 dark:bg-indigo-950/40 text-indigo-900 dark:text-indigo-100'
          : 'border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600 text-slate-700 dark:text-slate-300'
      }`}
    >
      {children}
    </button>
  )
}

function ScaleRow({
  value,
  onChange,
}: {
  value: number | null
  onChange: (v: number) => void
}) {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
      {SCALE_OPTIONS.map((opt) => (
        <OptionCard key={opt.value} selected={value === opt.value} onClick={() => onChange(opt.value)}>
          <span className="text-sm">{opt.label}</span>
        </OptionCard>
      ))}
    </div>
  )
}
