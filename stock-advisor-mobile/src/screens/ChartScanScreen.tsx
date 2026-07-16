import * as ImagePicker from 'expo-image-picker'
import { useState } from 'react'
import { ActivityIndicator, Image, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native'
import { Disclaimer } from '../components/Disclaimer'
import { analyzeChartImage } from '../lib/chartVision'
import type { ChartAnalysisResponse } from '../types'

type Status = 'idle' | 'loading' | 'error'

const SUPPORTED_MEDIA_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'] as const

// Native platforms re-encode picked images to JPEG when base64 is requested;
// web reads the original file's bytes/mimeType as-is. Trust the asset's
// mimeType when it's one we support, otherwise assume the native JPEG case.
function resolveMediaType(mimeType: string | null | undefined): (typeof SUPPORTED_MEDIA_TYPES)[number] {
  if (mimeType && (SUPPORTED_MEDIA_TYPES as readonly string[]).includes(mimeType)) {
    return mimeType as (typeof SUPPORTED_MEDIA_TYPES)[number]
  }
  return 'image/jpeg'
}

const TREND_LABEL: Record<string, string> = {
  uptrend: 'Uptrend',
  downtrend: 'Downtrend',
  sideways: 'Sideways / range-bound',
  unclear: 'Unclear',
}

const TREND_COLOR: Record<string, { bg: string; fg: string }> = {
  uptrend: { bg: '#dcfce7', fg: '#166534' },
  downtrend: { bg: '#fee2e2', fg: '#991b1b' },
  sideways: { bg: '#fef3c7', fg: '#92400e' },
  unclear: { bg: '#e2e8f0', fg: '#334155' },
}

export function ChartScanScreen({ onBack }: { onBack: () => void }) {
  const [imageUri, setImageUri] = useState<string | null>(null)
  const [imageBase64, setImageBase64] = useState<string | null>(null)
  const [mediaType, setMediaType] = useState<string>('image/jpeg')
  const [status, setStatus] = useState<Status>('idle')
  const [error, setError] = useState<string | null>(null)
  const [result, setResult] = useState<ChartAnalysisResponse | null>(null)

  function reset() {
    setImageUri(null)
    setImageBase64(null)
    setMediaType('image/jpeg')
    setStatus('idle')
    setError(null)
    setResult(null)
  }

  async function pickFrom(source: 'camera' | 'library') {
    reset()

    const permission =
      source === 'camera'
        ? await ImagePicker.requestCameraPermissionsAsync()
        : await ImagePicker.requestMediaLibraryPermissionsAsync()
    if (!permission.granted) {
      setError('Permission was not granted.')
      setStatus('error')
      return
    }

    const pickerResult =
      source === 'camera'
        ? await ImagePicker.launchCameraAsync({ base64: true, quality: 0.7 })
        : await ImagePicker.launchImageLibraryAsync({ base64: true, quality: 0.7 })

    if (pickerResult.canceled || !pickerResult.assets[0]) return

    const asset = pickerResult.assets[0]
    if (!asset.base64) {
      setError('Could not read the selected image.')
      setStatus('error')
      return
    }

    setImageUri(asset.uri)
    setImageBase64(asset.base64)
    setMediaType(resolveMediaType(asset.mimeType))
  }

  async function handleAnalyze() {
    if (!imageBase64) return
    setStatus('loading')
    setError(null)
    try {
      const response = await analyzeChartImage(imageBase64, mediaType)
      setResult(response)
      setStatus('idle')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong analyzing this image.')
      setStatus('error')
    }
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Pressable onPress={onBack} hitSlop={12}>
        <Text style={styles.back}>‹ Watchlist</Text>
      </Pressable>

      <Text style={styles.title}>Scan a chart</Text>
      <Text style={styles.subtitle}>
        Take a photo or upload a screenshot of any stock chart and get an AI reading of what it shows.
      </Text>

      {!imageUri && (
        <View style={styles.pickerRow}>
          <Pressable style={styles.pickerButton} onPress={() => pickFrom('camera')}>
            <Text style={styles.pickerButtonText}>Take Photo</Text>
          </Pressable>
          <Pressable style={styles.pickerButton} onPress={() => pickFrom('library')}>
            <Text style={styles.pickerButtonText}>Choose from Library</Text>
          </Pressable>
        </View>
      )}

      {imageUri && (
        <View style={styles.previewBlock}>
          <Image source={{ uri: imageUri }} style={styles.preview} resizeMode="contain" />
          <View style={styles.previewActions}>
            <Pressable style={styles.secondaryButton} onPress={reset}>
              <Text style={styles.secondaryButtonText}>Choose a different image</Text>
            </Pressable>
            {!result && (
              <Pressable
                style={[styles.primaryButton, status === 'loading' && styles.disabledButton]}
                onPress={handleAnalyze}
                disabled={status === 'loading'}
              >
                {status === 'loading' ? (
                  <ActivityIndicator color="#fff" size="small" />
                ) : (
                  <Text style={styles.primaryButtonText}>Analyze chart</Text>
                )}
              </Pressable>
            )}
          </View>
        </View>
      )}

      {status === 'error' && error && <Text style={styles.errorText}>{error}</Text>}

      {result && (
        <View style={styles.resultBlock}>
          {result.source === 'mock' && (
            <Text style={styles.mockBanner}>
              Mock response — the backend has no Anthropic API key configured, so this is a
              placeholder, not a real AI reading.
            </Text>
          )}

          <View
            style={[
              styles.trendBadge,
              { backgroundColor: TREND_COLOR[result.analysis.trend].bg },
            ]}
          >
            <Text style={[styles.trendBadgeText, { color: TREND_COLOR[result.analysis.trend].fg }]}>
              {TREND_LABEL[result.analysis.trend]}
            </Text>
          </View>

          <Text style={styles.summary}>{result.analysis.summary}</Text>

          {result.analysis.readableTicker && (
            <Text style={styles.metaLine}>Ticker read from image: {result.analysis.readableTicker}</Text>
          )}
          {result.analysis.timeframe && (
            <Text style={styles.metaLine}>Timeframe: {result.analysis.timeframe}</Text>
          )}
          <Text style={styles.metaLine}>Model confidence: {result.analysis.confidence}</Text>

          {result.analysis.observations.length > 0 && (
            <View style={styles.observations}>
              <Text style={styles.observationsTitle}>What the AI noticed</Text>
              {result.analysis.observations.map((obs, i) => (
                <Text key={i} style={styles.observationItem}>
                  • {obs}
                </Text>
              ))}
            </View>
          )}

          <View style={styles.disclaimerBox}>
            <Disclaimer />
            <Text style={styles.aiDisclaimer}>
              This reading was generated by an AI vision model interpreting the image you provided.
              It is not verified against live market data and the model can misread details in a
              photo — treat it as a starting point for your own research, not a fact.
            </Text>
          </View>
        </View>
      )}
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#ffffff' },
  content: { padding: 16, paddingBottom: 48 },
  back: { fontSize: 14, color: '#6366f1', marginBottom: 12 },
  title: { fontSize: 22, fontWeight: '700', color: '#0f172a' },
  subtitle: { fontSize: 13, color: '#64748b', marginTop: 4, marginBottom: 20 },
  pickerRow: { gap: 12 },
  pickerButton: {
    borderWidth: 1,
    borderColor: '#e2e8f0',
    borderRadius: 8,
    paddingVertical: 14,
    alignItems: 'center',
  },
  pickerButtonText: { fontSize: 14, fontWeight: '600', color: '#334155' },
  previewBlock: { gap: 12 },
  preview: { width: '100%', height: 280, borderRadius: 8, backgroundColor: '#f1f5f9' },
  previewActions: { flexDirection: 'row', gap: 12, flexWrap: 'wrap' },
  secondaryButton: { paddingVertical: 10, paddingHorizontal: 4 },
  secondaryButtonText: { fontSize: 13, color: '#6366f1' },
  primaryButton: {
    flex: 1,
    backgroundColor: '#6366f1',
    borderRadius: 8,
    paddingVertical: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  disabledButton: { opacity: 0.6 },
  primaryButtonText: { color: '#ffffff', fontSize: 14, fontWeight: '600' },
  errorText: { fontSize: 13, color: '#dc2626', marginTop: 16 },
  resultBlock: { marginTop: 24, gap: 12 },
  mockBanner: {
    fontSize: 12,
    color: '#92400e',
    backgroundColor: '#fef3c7',
    padding: 10,
    borderRadius: 8,
  },
  trendBadge: { alignSelf: 'flex-start', paddingHorizontal: 12, paddingVertical: 5, borderRadius: 999 },
  trendBadgeText: { fontSize: 13, fontWeight: '700' },
  summary: { fontSize: 15, color: '#1e293b', lineHeight: 22 },
  metaLine: { fontSize: 12, color: '#64748b' },
  observations: { marginTop: 4, gap: 6 },
  observationsTitle: { fontSize: 13, fontWeight: '600', color: '#334155', marginBottom: 2 },
  observationItem: { fontSize: 13, color: '#475569', lineHeight: 19 },
  disclaimerBox: { marginTop: 12, gap: 8 },
  aiDisclaimer: { fontSize: 12, color: '#64748b', lineHeight: 18 },
})
