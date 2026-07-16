import { useState } from 'react'
import { Dashboard } from './components/Dashboard'
import { Questionnaire } from './components/Questionnaire'
import { buildProfile } from './lib/recommend'
import { clearProfile, loadProfile, saveProfile } from './lib/storage'
import type { Profile, QuizAnswers } from './types'

function App() {
  const [profile, setProfile] = useState<Profile | null>(() => loadProfile())

  function handleComplete(answers: QuizAnswers) {
    const next = buildProfile(answers)
    saveProfile(next)
    setProfile(next)
  }

  function handleRetake() {
    clearProfile()
    setProfile(null)
  }

  return (
    <div className="min-h-screen bg-white dark:bg-slate-950">
      <header className="border-b border-slate-200 dark:border-slate-800">
        <div className="mx-auto max-w-3xl px-4 py-4 flex items-center gap-2">
          <span className="text-lg font-semibold text-slate-900 dark:text-slate-100">
            Stock Advisor
          </span>
          <span className="text-xs text-slate-400 dark:text-slate-500">(demo / educational)</span>
        </div>
      </header>

      <main>
        {profile ? (
          <Dashboard profile={profile} onRetake={handleRetake} />
        ) : (
          <Questionnaire onComplete={handleComplete} />
        )}
      </main>
    </div>
  )
}

export default App
