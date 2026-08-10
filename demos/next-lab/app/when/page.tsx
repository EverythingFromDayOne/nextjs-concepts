import { Suspense } from 'react'
import { BuildTimeSection, RequestTimeSection } from './sections'
import { ClientTimeSection } from './client-section'

export default function WhenPage() {
  return (
    <main>
      <BuildTimeSection />

      <Suspense fallback={<p aria-busy="true">Waiting for a request…</p>}>
        <RequestTimeSection />
      </Suspense>

      <ClientTimeSection />
    </main>
  )
}
