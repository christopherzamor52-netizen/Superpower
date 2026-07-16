import { useState } from 'react'
import { StyleSheet, Text, View } from 'react-native'
import Svg, { Path } from 'react-native-svg'
import { buildLinePath, linearScale, numericRange } from '../lib/chartScale'
import type { Candle, Indicators } from '../types'

const HEIGHT = 220
const PADDING = 12

export function PriceChart({ candles, indicators }: { candles: Candle[]; indicators: Indicators }) {
  const [width, setWidth] = useState(0)
  const closes = candles.map((c) => c.close)
  const [min, max] = numericRange([closes, indicators.sma20, indicators.sma50])

  const xScale = linearScale(0, Math.max(1, candles.length - 1), PADDING, width - PADDING)
  const yScale = linearScale(min, max, HEIGHT - PADDING, PADDING)

  return (
    <View style={styles.container}>
      <View onLayout={(e) => setWidth(e.nativeEvent.layout.width)} style={styles.chartArea}>
        {width > 0 && (
          <Svg width={width} height={HEIGHT}>
            <Path d={buildLinePath(indicators.sma50, xScale, yScale)} stroke="#f59e0b" strokeWidth={1.5} fill="none" />
            <Path d={buildLinePath(indicators.sma20, xScale, yScale)} stroke="#6366f1" strokeWidth={1.5} fill="none" />
            <Path d={buildLinePath(closes, xScale, yScale)} stroke="#0f172a" strokeWidth={2} fill="none" />
          </Svg>
        )}
      </View>
      <View style={styles.legendRow}>
        <LegendItem color="#0f172a" label="Price" />
        <LegendItem color="#6366f1" label="20-day avg" />
        <LegendItem color="#f59e0b" label="50-day avg" />
      </View>
    </View>
  )
}

function LegendItem({ color, label }: { color: string; label: string }) {
  return (
    <View style={styles.legendItem}>
      <View style={[styles.swatch, { backgroundColor: color }]} />
      <Text style={styles.legendText}>{label}</Text>
    </View>
  )
}

const styles = StyleSheet.create({
  container: { width: '100%' },
  chartArea: { width: '100%', height: HEIGHT },
  legendRow: { flexDirection: 'row', gap: 16, marginTop: 8, flexWrap: 'wrap' },
  legendItem: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  swatch: { width: 10, height: 10, borderRadius: 5 },
  legendText: { fontSize: 12, color: '#475569' },
})
