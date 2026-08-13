import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { getUsage } from '@/lib/billing'
import { assertCanViewUsage } from '@/lib/authz'
import { UsageChart } from '@/app/dashboard/parts'

export default function LeakFixedPage() {
  return (
    <main>
      <Suspense fallback={<p aria-busy="true">Loading usage…</p>}>
        <Usage />
      </Suspense>
    </main>
  )
}

async function Usage() {
  // Identity read here, outside every cached scope, and passed in as an
  // argument — so it lands in the compiler-derived key.
  const uid = (await cookies()).get('uid')?.value
  if (!uid) return <p>Sign in to see usage.</p>
  // Authorization runs on the request path, outside the cached scope it
  // guards. A cache hit is never a way to skip this.
  await assertCanViewUsage(uid, uid)
  return <UsageChart usage={await getUsage(uid)} />
}
