import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { getDashboardLeakC } from '@/lib/billing-leak-c'
import { UsageChart } from '@/app/dashboard/parts'

export default function LeakCPage() {
  return (
    <main>
      <Suspense fallback={<p aria-busy="true">Loading…</p>}>
        <LeakCBody />
      </Suspense>
    </main>
  )
}

async function LeakCBody() {
  const uid = (await cookies()).get('uid')?.value
  const scope = uid ? 'signed-in' : 'anonymous'
  const usage = await getDashboardLeakC(scope)
  return <UsageChart usage={usage} />
}
