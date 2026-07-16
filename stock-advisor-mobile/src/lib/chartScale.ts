export function linearScale(domainMin: number, domainMax: number, rangeMin: number, rangeMax: number) {
  const domainSpan = domainMax - domainMin || 1
  return (value: number) => rangeMin + ((value - domainMin) / domainSpan) * (rangeMax - rangeMin)
}

// Builds an SVG path 'd' string from a series that may contain nulls
// (e.g. an indicator that hasn't "warmed up" yet), lifting the pen at gaps.
export function buildLinePath(
  values: (number | null)[],
  xScale: (i: number) => number,
  yScale: (v: number) => number,
): string {
  const parts: string[] = []
  let penDown = false
  values.forEach((v, i) => {
    if (v === null) {
      penDown = false
      return
    }
    const x = xScale(i)
    const y = yScale(v)
    parts.push(`${penDown ? 'L' : 'M'} ${x.toFixed(2)} ${y.toFixed(2)}`)
    penDown = true
  })
  return parts.join(' ')
}

export function numericRange(values: (number | null)[][]): [number, number] {
  const flat = values.flat().filter((v): v is number => v !== null)
  if (flat.length === 0) return [0, 1]
  return [Math.min(...flat), Math.max(...flat)]
}
