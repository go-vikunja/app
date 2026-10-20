const colorProperties = {
  text: '--text',
  background: '--background',
  primary: '--primary',
  outline: '--outline',
  surface: '--surface',
  error: '--error',
  selection: '--selection',
  link: '--link',
  codeBackground: '--code-background',
}

const hexColor = /^#(?:[0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i
const functionalColor = /^rgba?\(\s*[\d.]+%?\s*(?:,\s*[\d.]+%?\s*){2}(?:,\s*[\d.]+%?\s*)?\)$/i

// A CSS colour string, or a Flutter ARGB integer (0xAARRGGBB).
export function cssColor(value) {
  if (typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= 0xffffffff) {
    const alpha = Math.round(((value >>> 24) & 0xff) / 0.255) / 1000
    return `rgba(${(value >>> 16) & 0xff}, ${(value >>> 8) & 0xff}, ${value & 0xff}, ${alpha})`
  }
  if (typeof value !== 'string') return null
  const trimmed = value.trim()
  return hexColor.test(trimmed) || functionalColor.test(trimmed) ? trimmed : null
}

export function applyTheme(root, theme) {
  if (theme === null || typeof theme !== 'object') return
  if (typeof theme.dark === 'boolean') root.style.colorScheme = theme.dark ? 'dark' : 'light'
  const colors = theme.colors !== null && typeof theme.colors === 'object' ? theme.colors : {}
  for (const [name, property] of Object.entries(colorProperties)) {
    const color = cssColor(colors[name])
    if (color !== null) root.style.setProperty(property, color)
  }
  const scale = Number(theme.fontScale)
  if (Number.isFinite(scale) && scale > 0) {
    root.style.setProperty('--font-scale', String(Math.min(Math.max(scale, 0.5), 4)))
  }
}
