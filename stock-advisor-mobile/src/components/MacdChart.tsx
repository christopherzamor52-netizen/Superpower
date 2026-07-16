import { useState } from 'react'
import { StyleSheet, Text, View } from 'react-native'
import Svg, { Line, Path, Rect } from 'react-native-svg'
import { buildLinePath, linearScale, numericRange } from '../lib/chartScale'
import type { Indicators } from '../types'

const HEIGHT = 100
const PADDING = 8

export function MacdChart({ indicators }: { indicators: Indicators }) {
  const [width, setWidth] = useState(0)
  const { macdLine, macdSignal, macdHistogram } = indicators
  const [min, max] = numericRange([macdLine, macdSignal, macdHistogram])
  const bound = Math.max(Math.abs(min), Math.abs(max), 0.01)

  const xScale = linearScale(0, Math.max(1, macdLine.length - 1), PADDING, width - PADDING)
  const yScale = linearScale(-bound, bound, HEIGHT - PADDING, PADDING)
  const zeroY = yScale(0)
  const barWidth = width > 0 ? Math.max(1, (width - PADDING * 2) / macdHistogram.length - 1) : 0

  return (
    <View>
      <Text style={styles.title}>MACD (12, 26, 9)</Text>
      <View onLayout={(e) => setWidth(e.nativeEvent.layout.width)} style={{ width: '100%', height: HEIGHT }}>
        {width > 0 && (
          <Svg width={width} height={HEIGHT}>
            <Line x1={PADDING} x2={width - PADDING} y1={zeroY} y2={zeroY} stroke="#e2e8f0" strokeWidth={1} />
            {macdHistogram.map((value, i) => {
              if (value === null) return null
              const x = xScale(i) - barWidth / 2
              const y = value >= 0 ? yScale(value) : zeroY
              const h = Math.abs(zeroY - yScale(value))
              return <Rect key={i} x={x} y={y} width={barWidth} height={h} fill={value >= 0 ? '#22c55e' : '#ef4444'} opacity={0.6} />
            })}
            <Path d={buildLinePath(macdLine, xScale, yScale)} stroke="#6366f1" strokeWidth={1.5} fill="none" />
            <Path d={buildLinePath(macdSignal, xScale, yScale)} stroke="#f59e0b" strokeWidth={1.5} fill="none" />
          </Svg>
        )}
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  title: { fontSize: 12, fontWeight: '600', color: '#475569', marginBottom: 4 },
})
