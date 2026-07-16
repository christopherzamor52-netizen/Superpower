import 'dotenv/config'
import cors from 'cors'
import express from 'express'
import { z } from 'zod'
import { analyzeChartImage } from './anthropicClient.js'
import { mockAnalyzeChartImage } from './mock.js'

const app = express()
app.use(cors())
app.use(express.json({ limit: '15mb' }))

const AnalyzeRequestSchema = z.object({
  imageBase64: z.string().min(1),
  mediaType: z.enum(['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
})

app.get('/health', (_req, res) => {
  res.json({ ok: true, mode: process.env.ANTHROPIC_API_KEY ? 'live' : 'mock' })
})

app.post('/analyze-chart', async (req, res) => {
  const parsed = AnalyzeRequestSchema.safeParse(req.body)
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.message })
    return
  }

  try {
    if (!process.env.ANTHROPIC_API_KEY) {
      res.json({ source: 'mock', analysis: mockAnalyzeChartImage() })
      return
    }

    const analysis = await analyzeChartImage(parsed.data.imageBase64, parsed.data.mediaType)
    res.json({ source: 'live', analysis })
  } catch (err) {
    console.error('analyze-chart failed:', err)
    res.status(502).json({ error: 'Failed to analyze the chart image. Please try again.' })
  }
})

const PORT = process.env.PORT ? Number(process.env.PORT) : 4000
app.listen(PORT, () => {
  console.log(`chart-vision-service listening on :${PORT} (mode: ${process.env.ANTHROPIC_API_KEY ? 'live' : 'mock'})`)
})
