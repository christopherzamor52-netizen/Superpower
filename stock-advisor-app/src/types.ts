export type Goal = 'retirement' | 'growth' | 'income' | 'short-term'

export type RiskLevel = 'conservative' | 'moderate' | 'aggressive'

export type AssetClass = 'stock' | 'bond-etf' | 'broad-etf' | 'cash'

export interface QuizAnswers {
  goal: Goal
  horizonYears: number
  reactionToDrop: number // 1-4, 1 = sell everything, 4 = buy more
  incomeStability: number // 1-4, 1 = unstable, 4 = very stable
  experience: number // 1-4, 1 = none, 4 = experienced
}

export interface Profile {
  goal: Goal
  horizonYears: number
  riskScore: number
  riskLevel: RiskLevel
  createdAt: string
}

export interface Allocation {
  broadEtf: number
  bondEtf: number
  individualStocks: number
  cash: number
}

export interface Instrument {
  ticker: string
  name: string
  assetClass: AssetClass
  sector: string
  riskLevel: RiskLevel
  blurb: string
}
