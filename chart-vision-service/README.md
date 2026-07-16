# chart-vision-service

A small backend for the "scan a chart" feature in `stock-advisor-mobile`. It
receives a chart screenshot/photo from the app, sends it to Claude's vision
API, and returns a structured reading (trend, notable observations, a plain-
language summary).

**Why a backend at all?** An Anthropic API key must never be embedded in a
client app — anyone could extract it from the app bundle and run up charges
on your account. This service holds the key server-side; the app only talks
to this service, never directly to Anthropic.

## Setup

```bash
npm install
cp .env.example .env
# edit .env and set ANTHROPIC_API_KEY=sk-ant-...
npm run dev
```

Without `ANTHROPIC_API_KEY` set, the server runs in **mock mode** — it
returns a clearly-labeled placeholder response instead of calling the real
API. This is intentional: it lets the mobile app be built and tested without
requiring a key, and is how this feature's plumbing was verified while being
built (see the caveat below).

## API

`POST /analyze-chart`

```json
{ "imageBase64": "<base64-encoded image>", "mediaType": "image/jpeg" }
```

`mediaType` must be one of `image/jpeg`, `image/png`, `image/webp`, `image/gif`.

Response:

```json
{
  "source": "live",
  "analysis": {
    "readableTicker": "AAPL",
    "timeframe": "1Y",
    "trend": "uptrend",
    "observations": ["..."],
    "summary": "...",
    "confidence": "medium"
  }
}
```

`source` is `"mock"` when no API key is configured.

## Model and prompt

Uses `claude-opus-4-8` with adaptive thinking and a Zod-validated structured
output schema (see `src/schema.ts`), via the official `@anthropic-ai/sdk`.
The prompt (`src/anthropicClient.ts`) explicitly tells the model not to
invent precise price levels it can't actually read off the image, and to
describe patterns qualitatively when exact numbers aren't legible.

## What was and wasn't verified here

This service was built and tested in a sandboxed environment with no
outbound network access to `api.anthropic.com` and no API key available, so
**the real, live vision call has never actually been exercised.** What was
verified:

- The request is constructed exactly per the official SDK's documented
  usage (`messages.parse` + `zodOutputFormat` + `output_config.format`).
- `api.anthropic.com` is reachable from this kind of environment in
  principle (confirmed via a plain HTTPS request, which correctly returned
  401 for lacking credentials — i.e. the network path works).
- The full pipeline — image picker → base64 encode → this service (in mock
  mode) → JSON response → mobile UI rendering — works end-to-end, using a
  real screenshot of a brokerage app's stock chart as the test image.

**Before relying on this in production, run it once with a real
`ANTHROPIC_API_KEY` and confirm the live response looks right** — the mock
path only proves the plumbing, not that the model's actual chart-reading
output is well-calibrated for your use case.

## Deploying

This is a plain Express server — deploy it anywhere that runs Node (Render,
Fly.io, Railway, a VPS, a container platform, etc.). Set `ANTHROPIC_API_KEY`
as a secret/environment variable on whatever platform you use; never commit
it. Then point the mobile app at the deployed URL via
`EXPO_PUBLIC_CHART_VISION_API_URL` (see `stock-advisor-mobile/src/config.ts`).
