import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native'
import { MacdChart } from '../components/MacdChart'
import { PriceChart } from '../components/PriceChart'
import { RsiChart } from '../components/RsiChart'
import { SignalBadge } from '../components/SignalBadge'
import { SignalChecklist } from '../components/SignalChecklist'
import { Disclaimer } from '../components/Disclaimer'
import { useTickerData } from '../lib/useTickerData'

export function StockDetailScreen({ symbol, onBack }: { symbol: string; onBack: () => void }) {
  const data = useTickerData(symbol)
  const lastCandle = data.candles[data.candles.length - 1]

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Pressable onPress={onBack} hitSlop={12}>
        <Text style={styles.back}>‹ Watchlist</Text>
      </Pressable>

      <View style={styles.headerRow}>
        <Text style={styles.symbol}>{symbol}</Text>
        {data.signal && <SignalBadge label={data.signal.label} />}
      </View>

      {data.status === 'loading' && (
        <View style={styles.centerBlock}>
          <ActivityIndicator size="large" color="#6366f1" />
          <Text style={styles.loadingText}>Loading chart…</Text>
        </View>
      )}

      {data.status === 'error' && (
        <View style={styles.centerBlock}>
          <Text style={styles.errorText}>{data.error}</Text>
        </View>
      )}

      {data.status === 'ready' && data.indicators && data.signal && (
        <>
          {lastCandle && <Text style={styles.price}>${lastCandle.close.toFixed(2)}</Text>}

          <Section title="Price, with 20/50-day averages">
            <PriceChart candles={data.candles} indicators={data.indicators} />
          </Section>

          <Section title="Momentum">
            <View style={styles.momentumRow}>
              <View style={styles.momentumHalf}>
                <RsiChart rsi={data.indicators.rsi14} />
              </View>
            </View>
            <MacdChart indicators={data.indicators} />
          </Section>

          <Section title="Why this signal">
            <SignalChecklist signal={data.signal} />
          </Section>

          <Disclaimer />
        </>
      )}
    </ScrollView>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#ffffff' },
  content: { padding: 16, paddingBottom: 48, gap: 4 },
  back: { fontSize: 14, color: '#6366f1', marginBottom: 12 },
  headerRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  symbol: { fontSize: 26, fontWeight: '700', color: '#0f172a' },
  price: { fontSize: 16, color: '#334155', marginTop: 4, marginBottom: 8 },
  centerBlock: { alignItems: 'center', paddingVertical: 48, gap: 8 },
  loadingText: { fontSize: 13, color: '#94a3b8' },
  errorText: { fontSize: 14, color: '#dc2626', textAlign: 'center' },
  section: { marginTop: 20 },
  sectionTitle: { fontSize: 13, fontWeight: '600', color: '#334155', marginBottom: 10 },
  momentumRow: { marginBottom: 12 },
  momentumHalf: { width: '100%' },
})
