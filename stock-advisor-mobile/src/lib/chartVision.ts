import { CHART_VISION_API_URL } from '../config'
import type { ChartAnalysisResponse } from '../types'

export async function analyzeChartImage(base64: string, mediaType: string): Promise<ChartAnalysisResponse> {
  const response = await fetch(`${CHART_VISION_API_URL}/analyze-chart`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ imageBase64: base64, mediaType }),
  })

  if (!response.ok) {
    throw new Error(`Chart analysis request failed with status ${response.status}`)
  }

  return (await response.json()) as ChartAnalysisResponse
}
