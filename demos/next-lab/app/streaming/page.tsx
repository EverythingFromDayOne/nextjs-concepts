import { Suspense } from 'react'
import {
  Summary,
  RevenuePanel,
  TrafficPanel,
  ErrorsPanel,
  PanelSkeleton,
} from './panels'

/**
 * Three sibling boundaries, one per panel. Each resolves independently, so
 * the 1500ms panel never delays the 200ms one. <Summary /> sits outside any
 * boundary because it is cached — cached work resolves during the prerender
 * and therefore does not need a hole.
 */
export default function StreamingPage() {
  return (
    <main>
      <Summary />

      <Suspense fallback={<PanelSkeleton title="Revenue" rows={3} />}>
        <RevenuePanel />
      </Suspense>

      <Suspense fallback={<PanelSkeleton title="Traffic" rows={4} />}>
        <TrafficPanel />
      </Suspense>

      <Suspense fallback={<PanelSkeleton title="Errors" rows={2} />}>
        <ErrorsPanel />
      </Suspense>
    </main>
  )
}
