import { useState } from 'react'
import { FlatList, StyleSheet, Text, TextInput, View } from 'react-native'
import { WatchlistRow } from '../components/WatchlistRow'
import { DEFAULT_WATCHLIST } from '../data/watchlist'
import type { WatchlistTicker } from '../types'

export function WatchlistScreen({ onSelect }: { onSelect: (symbol: string) => void }) {
  const [custom, setCustom] = useState<WatchlistTicker[]>([])
  const [query, setQuery] = useState('')

  const tickers = [...custom, ...DEFAULT_WATCHLIST]

  function handleAdd() {
    const symbol = query.trim().toUpperCase()
    if (!symbol) return
    if (tickers.some((t) => t.symbol === symbol)) {
      setQuery('')
      onSelect(symbol)
      return
    }
    setCustom((prev) => [{ symbol, name: symbol }, ...prev])
    setQuery('')
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Stock Advisor</Text>
        <Text style={styles.subtitle}>Educational technical-analysis signals, not financial advice</Text>
      </View>

      <TextInput
        value={query}
        onChangeText={setQuery}
        placeholder="Add any ticker, e.g. NFLX"
        placeholderTextColor="#94a3b8"
        autoCapitalize="characters"
        autoCorrect={false}
        style={styles.input}
        onSubmitEditing={handleAdd}
        returnKeyType="done"
      />

      <FlatList
        data={tickers}
        keyExtractor={(item, index) => `${item.symbol}-${index}`}
        renderItem={({ item }) => <WatchlistRow ticker={item} onPress={() => onSelect(item.symbol)} />}
        ItemSeparatorComponent={() => <View style={styles.separator} />}
        contentContainerStyle={styles.listContent}
      />
    </View>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#ffffff' },
  header: { paddingHorizontal: 16, paddingTop: 16, paddingBottom: 8 },
  title: { fontSize: 22, fontWeight: '700', color: '#0f172a' },
  subtitle: { fontSize: 12, color: '#64748b', marginTop: 4 },
  input: {
    marginHorizontal: 16,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 14,
    color: '#0f172a',
  },
  listContent: { paddingBottom: 24 },
  separator: { height: 1, backgroundColor: '#f1f5f9', marginLeft: 16 },
})
