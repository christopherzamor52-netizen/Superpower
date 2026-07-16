import { StyleSheet, Text, View } from 'react-native'
import type { SignalLabel } from '../types'

const CONFIG: Record<SignalLabel, { bg: string; fg: string; text: string }> = {
  buy: { bg: '#dcfce7', fg: '#166534', text: 'BUY SIGNAL' },
  watch: { bg: '#fef3c7', fg: '#92400e', text: 'WATCH' },
  wait: { bg: '#e2e8f0', fg: '#334155', text: 'WAIT' },
}

export function SignalBadge({ label }: { label: SignalLabel }) {
  const cfg = CONFIG[label]
  return (
    <View style={[styles.badge, { backgroundColor: cfg.bg }]}>
      <Text style={[styles.text, { color: cfg.fg }]}>{cfg.text}</Text>
    </View>
  )
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 999,
    alignSelf: 'flex-start',
  },
  text: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.3,
  },
})
