import { StatusBar } from 'expo-status-bar'
import { useState } from 'react'
import { SafeAreaView, StyleSheet } from 'react-native'
import { ChartScanScreen } from './src/screens/ChartScanScreen'
import { StockDetailScreen } from './src/screens/StockDetailScreen'
import { WatchlistScreen } from './src/screens/WatchlistScreen'

type Screen = { name: 'watchlist' } | { name: 'detail'; symbol: string } | { name: 'scan' }

export default function App() {
  const [screen, setScreen] = useState<Screen>({ name: 'watchlist' })

  return (
    <SafeAreaView style={styles.container}>
      {screen.name === 'detail' && (
        <StockDetailScreen symbol={screen.symbol} onBack={() => setScreen({ name: 'watchlist' })} />
      )}
      {screen.name === 'scan' && <ChartScanScreen onBack={() => setScreen({ name: 'watchlist' })} />}
      {screen.name === 'watchlist' && (
        <WatchlistScreen
          onSelect={(symbol) => setScreen({ name: 'detail', symbol })}
          onScanChart={() => setScreen({ name: 'scan' })}
        />
      )}
      <StatusBar style="auto" />
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#ffffff' },
})
