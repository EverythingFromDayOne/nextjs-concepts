import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { getDashboardLeakA } from '@/lib/billing-leak-a'
import { UsageChart } from '@/app/dashboard/parts'

export default function LeakAPage() {
  return (
    <main>
      <Suspense fallback={<p aria-busy="true">Loading…</p>}>
        <LeakABody />
      </Suspense>
    </main>
  )
}

async function LeakABody() {
  // Uncached identity read — then call the cached function that also reads cookies.
  const uid = (await cookies()).get('uid')?.value
  void uid
  const usage = await getDashboardLeakA()
  return <UsageChart usage={usage} />
}
