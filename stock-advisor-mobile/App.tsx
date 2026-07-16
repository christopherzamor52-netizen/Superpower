import { StatusBar } from 'expo-status-bar'
import { useState } from 'react'
import { SafeAreaView, StyleSheet } from 'react-native'
import { StockDetailScreen } from './src/screens/StockDetailScreen'
import { WatchlistScreen } from './src/screens/WatchlistScreen'

export default function App() {
  const [selectedSymbol, setSelectedSymbol] = useState<string | null>(null)

  return (
    <SafeAreaView style={styles.container}>
      {selectedSymbol ? (
        <StockDetailScreen symbol={selectedSymbol} onBack={() => setSelectedSymbol(null)} />
      ) : (
        <WatchlistScreen onSelect={setSelectedSymbol} />
      )}
      <StatusBar style="auto" />
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#ffffff' },
})
