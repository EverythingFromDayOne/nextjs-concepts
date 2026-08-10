import { Suspense } from 'react'
import {
  Summary,
  RevenuePanel,
  TrafficPanel,
  ErrorsPanel,
  PanelSkeleton,
} from '../streaming/panels'

/**
 * Identical data, identical latencies, one boundary instead of three.
 *
 * Two costs are predicted, and §5 measures both: nothing appears until the
 * slowest child resolves, and the cached <Summary /> is dragged out of the
 * shell because it now sits inside a hole.
 */
export default function CoarseStreamingPage() {
  return (
    <main>
      <Suspense fallback={<PanelSkeleton title="Weekly report" rows={4} />}>
        <Summary />
        <RevenuePanel />
        <TrafficPanel />
        <ErrorsPanel />
      </Suspense>
    </main>
  )
}
