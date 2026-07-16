import { z } from 'zod'

export const ChartAnalysisSchema = z.object({
  readableTicker: z
    .string()
    .nullable()
    .describe('Ticker symbol visible in the image, or null if none is legible'),
  timeframe: z
    .string()
    .nullable()
    .describe('Chart timeframe/range shown (e.g. "1D", "1Y", "5Y"), or null if not legible'),
  trend: z
    .enum(['uptrend', 'downtrend', 'sideways', 'unclear'])
    .describe('Overall visual price trend shown in the chart'),
  observations: z
    .array(z.string())
    .max(6)
    .describe(
      'Specific, concrete observations about what is visible: chart patterns, notable ' +
        'support/resistance levels (described qualitatively, not invented precise numbers), ' +
        'volume behavior, candle color patterns. Only include what is actually visible.',
    ),
  summary: z.string().describe('A 2-4 sentence plain-language summary of what the chart shows'),
  confidence: z
    .enum(['low', 'medium', 'high'])
    .describe('How confident the model is in this reading, given image clarity and legibility'),
})

export type ChartAnalysis = z.infer<typeof ChartAnalysisSchema>
