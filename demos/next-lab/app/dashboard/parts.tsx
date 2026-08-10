import type { Alert, Plan, Usage } from '@/lib/db'
import { formatPrice } from '@/lib/db'

export function PlanTable({ plans }: { plans: Plan[] }) {
  return (
    <table>
      <tbody>
        {plans.map((p) => (
          <tr key={p.id}><td>{p.name}</td><td>{formatPrice(p.priceCents)}</td></tr>
        ))}
      </tbody>
    </table>
  )
}

export function UsageChart({ usage }: { usage: Usage }) {
  return (
    <p data-uid={usage.uid}>
      {usage.requests.toLocaleString('en-US')} requests · {usage.storageMb} MB
    </p>
  )
}

export function AlertBanner({ alerts }: { alerts: Alert[] }) {
  if (alerts.length === 0) return null
  return <ul>{alerts.map((a) => <li key={a.id}>{a.message}</li>)}</ul>
}

export function PlanTableSkeleton() {
  return <p aria-busy="true">Loading plans…</p>
}

export function UsageSkeleton() {
  return <p aria-busy="true">Loading usage…</p>
}
