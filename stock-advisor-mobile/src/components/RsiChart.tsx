import { useState } from 'react'
import { StyleSheet, Text, View } from 'react-native'
import Svg, { Line, Path } from 'react-native-svg'
import { buildLinePath, linearScale } from '../lib/chartScale'
import type { Indicators } from '../types'

const HEIGHT = 90
const PADDING = 8

export function RsiChart({ rsi }: { rsi: Indicators['rsi14'] }) {
  const [width, setWidth] = useState(0)
  const xScale = linearScale(0, Math.max(1, rsi.length - 1), PADDING, width - PADDING)
  const yScale = linearScale(0, 100, HEIGHT - PADDING, PADDING)

  return (
    <View>
      <Text style={styles.title}>RSI (14)</Text>
      <View onLayout={(e) => setWidth(e.nativeEvent.layout.width)} style={{ width: '100%', height: HEIGHT }}>
        {width > 0 && (
          <Svg width={width} height={HEIGHT}>
            <Line x1={PADDING} x2={width - PADDING} y1={yScale(70)} y2={yScale(70)} stroke="#fecaca" strokeWidth={1} strokeDasharray="4 3" />
            <Line x1={PADDING} x2={width - PADDING} y1={yScale(30)} y2={yScale(30)} stroke="#bbf7d0" strokeWidth={1} strokeDasharray="4 3" />
            <Path d={buildLinePath(rsi, xScale, yScale)} stroke="#7c3aed" strokeWidth={1.5} fill="none" />
          </Svg>
        )}
      </View>
      <View style={styles.captionRow}>
        <Text style={styles.caption}>30 = oversold</Text>
        <Text style={styles.caption}>70 = overbought</Text>
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  title: { fontSize: 12, fontWeight: '600', color: '#475569', marginBottom: 4 },
  captionRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 2 },
  caption: { fontSize: 11, color: '#94a3b8' },
})
