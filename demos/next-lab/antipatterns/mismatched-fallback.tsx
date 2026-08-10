// antipattern: a centred spinner standing in for a four-row table. The
// shell reserves the wrong space, so the swap shifts the layout — which
// measures worse than having shown nothing. Extract-only; never compiled.
import { Suspense } from 'react'
import { TrafficPanel } from '../app/streaming/panels'

export function MismatchedFallback() {
  return (
    <Suspense fallback={<div className="spinner" />}>
      <TrafficPanel />
    </Suspense>
  )
}
