import type { Profile } from '../types'

const KEY = 'stock-advisor.profile'

export function loadProfile(): Profile | null {
  const raw = localStorage.getItem(KEY)
  if (!raw) return null
  try {
    return JSON.parse(raw) as Profile
  } catch {
    return null
  }
}

export function saveProfile(profile: Profile): void {
  localStorage.setItem(KEY, JSON.stringify(profile))
}

export function clearProfile(): void {
  localStorage.removeItem(KEY)
}
