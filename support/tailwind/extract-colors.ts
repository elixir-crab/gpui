import colors from './node_modules/tailwindcss/src/public/colors.js'
import type { DefaultColors } from './node_modules/tailwindcss/types/generated/colors'

const families = [
  'slate',
  'gray',
  'zinc',
  'neutral',
  'stone',
  'red',
  'orange',
  'amber',
  'yellow',
  'lime',
  'green',
  'emerald',
  'teal',
  'cyan',
  'sky',
  'blue',
  'indigo',
  'violet',
  'purple',
  'fuchsia',
  'pink',
  'rose'
] as const satisfies readonly (keyof DefaultColors)[]

type Family = (typeof families)[number]
type Palette = Pick<DefaultColors, Family | 'black' | 'white' | 'transparent'>

const palette = Object.fromEntries(families.map((family) => [family, colors[family]])) as Pick<
  DefaultColors,
  Family
>

const extracted: Palette = {
  ...palette,
  black: colors.black,
  white: colors.white,
  transparent: colors.transparent
}

globalThis.__gpuiTailwindColors = extracted

declare global {
  var __gpuiTailwindColors: Palette
}
