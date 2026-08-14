import { Suspense } from 'react'
import { getDashboardPrivate } from '@/lib/billing-private'
import { UsageChart } from '@/app/dashboard/parts'

export default function LeakPrivatePage() {
  return (
    <main>
      <Suspense fallback={<p aria-busy="true">Loading…</p>}>
        <LeakPrivateBody />
      </Suspense>
    </main>
  )
}

async function LeakPrivateBody() {
  const usage = await getDashboardPrivate()
  return <UsageChart usage={usage} />
}
