import type { ChartAnalysis } from './schema.js'

// Used when ANTHROPIC_API_KEY is not configured, so the client app and this
// service's plumbing can be developed/tested without a real API key.
export function mockAnalyzeChartImage(): ChartAnalysis {
  return {
    readableTicker: null,
    timeframe: null,
    trend: 'unclear',
    observations: [
      'MOCK RESPONSE - no ANTHROPIC_API_KEY is configured on this server.',
      'Set ANTHROPIC_API_KEY in chart-vision-service/.env to get a real AI reading.',
    ],
    summary:
      'This is a placeholder response because the server has no Anthropic API key configured. ' +
      'It exists only to let the app be developed and tested end-to-end without live API calls.',
    confidence: 'low',
  }
}
