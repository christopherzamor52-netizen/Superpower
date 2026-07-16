import { StyleSheet, Text, View } from 'react-native'

export function Disclaimer() {
  return (
    <View style={styles.box}>
      <Text style={styles.text}>
        <Text style={styles.bold}>Educational tool only, not financial advice.</Text> Signals come
        from simple, transparent technical-analysis rules (moving averages, RSI, MACD) applied to
        recent price history — not a prediction, not personalized, and not a substitute for advice
        from a licensed financial professional. Past patterns do not guarantee future results, and
        investing involves risk, including loss of principal.
      </Text>
    </View>
  )
}

const styles = StyleSheet.create({
  box: {
    borderWidth: 1,
    borderColor: '#e2e8f0',
    borderRadius: 8,
    padding: 12,
  },
  text: {
    fontSize: 12,
    lineHeight: 18,
    color: '#64748b',
  },
  bold: {
    fontWeight: '700',
    color: '#334155',
  },
})
