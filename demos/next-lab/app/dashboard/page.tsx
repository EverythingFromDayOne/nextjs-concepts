import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { connection } from 'next/server'
import { getPlans, getUsage } from '@/lib/billing'
import { getAlerts } from '@/lib/status'
import {
  PlanTable, UsageChart, AlertBanner, PlanTableSkeleton, UsageSkeleton,
} from './parts'

export default function DashboardPage() {
  return (
    <main>
      <Suspense fallback={<PlanTableSkeleton />}><Plans /></Suspense>
      <Suspense fallback={<UsageSkeleton />}><Usage /></Suspense>
      <Suspense fallback={null}><Alerts /></Suspense>
      <Suspense fallback={null}><LastRefreshed /></Suspense>
    </main>
  )
}

async function Plans() {
  return <PlanTable plans={await getPlans()} />
}

async function Usage() {
  // Runtime read, outside the cached scope. The value is passed in.
  const uid = (await cookies()).get('uid')?.value
  if (!uid) return <p>Sign in to see usage.</p>
  return <UsageChart usage={await getUsage(uid)} />
}

async function Alerts() {
  return <AlertBanner alerts={await getAlerts()} />
}

async function LastRefreshed() {
  await connection()
  return <time>{new Date().toLocaleTimeString('en-US')}</time>
}
