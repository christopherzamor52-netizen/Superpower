import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native'
import { useTickerData } from '../lib/useTickerData'
import type { WatchlistTicker } from '../types'
import { SignalBadge } from './SignalBadge'

export function WatchlistRow({ ticker, onPress }: { ticker: WatchlistTicker; onPress: () => void }) {
  const data = useTickerData(ticker.symbol)
  const lastCandle = data.candles[data.candles.length - 1]
  const prevCandle = data.candles[data.candles.length - 2]
  const change =
    lastCandle && prevCandle ? ((lastCandle.close - prevCandle.close) / prevCandle.close) * 100 : null

  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
      <View style={styles.left}>
        <Text style={styles.symbol}>{ticker.symbol}</Text>
        <Text style={styles.name} numberOfLines={1}>
          {ticker.name}
        </Text>
      </View>
      <View style={styles.right}>
        {data.status === 'loading' && <ActivityIndicator size="small" color="#94a3b8" />}
        {data.status === 'error' && <Text style={styles.errorText}>Unavailable</Text>}
        {data.status === 'ready' && lastCandle && (
          <>
            <View style={styles.priceBlock}>
              <Text style={styles.price}>${lastCandle.close.toFixed(2)}</Text>
              {change !== null && (
                <Text style={[styles.change, change >= 0 ? styles.up : styles.down]}>
                  {change >= 0 ? '+' : ''}
                  {change.toFixed(2)}%
                </Text>
              )}
            </View>
            {data.signal && <SignalBadge label={data.signal.label} />}
          </>
        )}
      </View>
    </Pressable>
  )
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  pressed: { backgroundColor: '#f8fafc' },
  left: { flex: 1, marginRight: 12 },
  symbol: { fontSize: 15, fontWeight: '700', color: '#0f172a' },
  name: { fontSize: 12, color: '#64748b', marginTop: 2 },
  right: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  priceBlock: { alignItems: 'flex-end' },
  price: { fontSize: 14, fontWeight: '600', color: '#0f172a' },
  change: { fontSize: 12, marginTop: 2 },
  up: { color: '#16a34a' },
  down: { color: '#dc2626' },
  errorText: { fontSize: 12, color: '#94a3b8', fontStyle: 'italic' },
})
