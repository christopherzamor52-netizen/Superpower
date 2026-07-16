import { INSTRUMENTS } from '../data/instruments'
import type { Allocation, Goal, Instrument, Profile, QuizAnswers, RiskLevel } from '../types'

export function scoreRisk(answers: QuizAnswers): number {
  // Each sub-score is 1-4; average them, then nudge for very short/long horizons.
  const base =
    (answers.reactionToDrop + answers.incomeStability + answers.experience) / 3

  const horizonAdjustment =
    answers.horizonYears >= 15 ? 0.4 : answers.horizonYears <= 3 ? -0.6 : 0

  return Math.min(4, Math.max(1, base + horizonAdjustment))
}

export function riskLevelFromScore(score: number): RiskLevel {
  if (score < 2.2) return 'conservative'
  if (score < 3.2) return 'moderate'
  return 'aggressive'
}

export function buildProfile(answers: QuizAnswers): Profile {
  const riskScore = scoreRisk(answers)
  return {
    goal: answers.goal,
    horizonYears: answers.horizonYears,
    riskScore,
    riskLevel: riskLevelFromScore(riskScore),
    createdAt: new Date().toISOString(),
  }
}

const BASE_ALLOCATIONS: Record<RiskLevel, Allocation> = {
  conservative: { broadEtf: 45, bondEtf: 40, individualStocks: 5, cash: 10 },
  moderate: { broadEtf: 50, bondEtf: 20, individualStocks: 25, cash: 5 },
  aggressive: { broadEtf: 45, bondEtf: 5, individualStocks: 48, cash: 2 },
}

// Nudge allocation based on stated goal, on top of the risk-driven base split.
const GOAL_ADJUSTMENTS: Record<Goal, Partial<Allocation>> = {
  retirement: { bondEtf: 5 }, // slightly more ballast for a long, steady goal
  growth: { individualStocks: 5 },
  income: { bondEtf: 10, broadEtf: -5 }, // favor income-generating holdings
  'short-term': { cash: 10, individualStocks: -10 }, // capital preservation for near-term needs
}

export function buildAllocation(profile: Profile): Allocation {
  const base = { ...BASE_ALLOCATIONS[profile.riskLevel] }
  const adjustment = GOAL_ADJUSTMENTS[profile.goal]

  const merged: Allocation = {
    broadEtf: base.broadEtf + (adjustment.broadEtf ?? 0),
    bondEtf: base.bondEtf + (adjustment.bondEtf ?? 0),
    individualStocks: base.individualStocks + (adjustment.individualStocks ?? 0),
    cash: base.cash + (adjustment.cash ?? 0),
  }

  // Clamp negatives and renormalize to 100.
  const clamped = Object.fromEntries(
    Object.entries(merged).map(([k, v]) => [k, Math.max(0, v)]),
  ) as unknown as Allocation
  const total = Object.values(clamped).reduce((a, b) => a + b, 0)
  const scale = 100 / total

  return {
    broadEtf: Math.round(clamped.broadEtf * scale),
    bondEtf: Math.round(clamped.bondEtf * scale),
    individualStocks: Math.round(clamped.individualStocks * scale),
    cash: Math.round(clamped.cash * scale),
  }
}

// Risk levels a profile is comfortable seeing individual stock picks from:
// conservative investors only see conservative picks, aggressive investors
// see the full range (they've already indicated a high risk tolerance).
const VISIBLE_RISK_LEVELS: Record<RiskLevel, RiskLevel[]> = {
  conservative: ['conservative'],
  moderate: ['conservative', 'moderate'],
  aggressive: ['conservative', 'moderate', 'aggressive'],
}

export function recommendInstruments(profile: Profile, limit = 6): Instrument[] {
  const visible = VISIBLE_RISK_LEVELS[profile.riskLevel]
  const pool = INSTRUMENTS.filter((i) => visible.includes(i.riskLevel))

  // Prefer picks matching the investor's own risk level first, then fill in
  // with steadier options, keeping sector variety.
  const sorted = [...pool].sort((a, b) => {
    const aMatch = a.riskLevel === profile.riskLevel ? 0 : 1
    const bMatch = b.riskLevel === profile.riskLevel ? 0 : 1
    return aMatch - bMatch
  })

  const seenSectors = new Set<string>()
  const picks: Instrument[] = []

  for (const instrument of sorted) {
    if (picks.length >= limit) break
    if (seenSectors.has(instrument.sector)) continue
    seenSectors.add(instrument.sector)
    picks.push(instrument)
  }

  for (const instrument of sorted) {
    if (picks.length >= limit) break
    if (!picks.includes(instrument)) picks.push(instrument)
  }

  return picks
}
