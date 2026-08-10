import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { getDashboardLeakB, rememberUid } from '@/lib/billing-leak-b'
import { UsageChart } from '@/app/dashboard/parts'

export default function LeakBPage() {
  return (
    <main>
      <Suspense fallback={<p aria-busy="true">Loading…</p>}>
        <LeakBBody />
      </Suspense>
    </main>
  )
}

async function LeakBBody() {
  const uid = (await cookies()).get('uid')?.value ?? 'anonymous'
  rememberUid(uid)
  const usage = await getDashboardLeakB()
  return <UsageChart usage={usage} />
}
