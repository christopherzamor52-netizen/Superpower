// Points at the chart-vision-service backend (see ../../chart-vision-service).
// Override for a physical device or deployed backend via EXPO_PUBLIC_CHART_VISION_API_URL.
export const CHART_VISION_API_URL =
  process.env.EXPO_PUBLIC_CHART_VISION_API_URL ?? 'http://localhost:4000'
