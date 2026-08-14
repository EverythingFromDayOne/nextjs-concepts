'use client'

import dynamic from 'next/dynamic'

// ssr: false skips server rendering entirely. The fallback is what lands
// in the HTML; the real component only exists after hydration.
export const HeavyWidgetClientOnly = dynamic(
  () => import('./heavy-widget').then((m) => m.HeavyWidget),
  { ssr: false, loading: () => <p>Loading widget…</p> }
)
