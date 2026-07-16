import { StyleSheet, Text, View } from 'react-native'
import type { Signal } from '../types'

export function SignalChecklist({ signal }: { signal: Signal }) {
  return (
    <View>
      <Text style={styles.heading}>
        {signal.score}/{signal.maxScore} bullish conditions met
      </Text>
      {signal.conditions.map((condition) => (
        <View key={condition.key} style={styles.row}>
          <Text style={[styles.mark, condition.met ? styles.markMet : styles.markUnmet]}>
            {condition.met ? '✓' : '·'}
          </Text>
          <Text style={[styles.label, condition.met && styles.labelMet]}>{condition.label}</Text>
        </View>
      ))}
    </View>
  )
}

const styles = StyleSheet.create({
  heading: { fontSize: 13, fontWeight: '600', color: '#334155', marginBottom: 8 },
  row: { flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 6 },
  mark: { width: 16, fontSize: 14, fontWeight: '700' },
  markMet: { color: '#16a34a' },
  markUnmet: { color: '#cbd5e1' },
  label: { fontSize: 13, color: '#64748b', flex: 1 },
  labelMet: { color: '#1e293b' },
})
