import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import { ChartAnalysisSchema, type ChartAnalysis } from './schema.js'

const client = new Anthropic()

const PROMPT = `You are looking at a screenshot of a stock or ETF price chart from a
brokerage/trading app. Read only what is visually present in the image.

Rules:
- Do not invent specific price levels, dates, or percentages that are not legible in the image.
- If something (ticker, timeframe, exact numbers) is not clearly legible, say so rather than guessing.
- Describe patterns qualitatively (e.g. "a multi-month sideways range before a breakout") rather
  than fabricating precise numeric support/resistance levels unless a gridline or label makes the
  exact value clear.
- This reading is for general/educational purposes only, not a trading recommendation - do not
  phrase output as "you should buy/sell", just describe what the chart shows.`

export async function analyzeChartImage(imageBase64: string, mediaType: string): Promise<ChartAnalysis> {
  const response = await client.messages.parse({
    model: 'claude-opus-4-8',
    max_tokens: 2048,
    thinking: { type: 'adaptive' },
    output_config: {
      format: zodOutputFormat(ChartAnalysisSchema),
    },
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: mediaType as 'image/jpeg' | 'image/png' | 'image/webp' | 'image/gif',
              data: imageBase64,
            },
          },
          { type: 'text', text: PROMPT },
        ],
      },
    ],
  })

  if (response.parsed_output === null) {
    throw new Error('Model response did not match the expected schema')
  }

  return response.parsed_output
}
