import type { Row } from '@/lib/db'
import { getSummary, getRevenue, getTraffic, getErrors } from '@/lib/report'
import { formatPrice } from '@/lib/db'

function Panel({ title, rows }: { title: string; rows: Row[] }) {
  return (
    <section>
      <h2>{title}</h2>
      <dl>
        {rows.map((r) => (
          <div key={r.label}>
            <dt>{r.label}</dt>
            <dd>{r.value}</dd>
          </div>
        ))}
      </dl>
    </section>
  )
}

/**
 * The fallback matches the resolved panel's shape: same heading, same row
 * count, same element structure. A fallback that does not match the layout
 * it replaces produces a visible shift, which reads as slower than showing
 * nothing at all.
 */
export function PanelSkeleton({ title, rows }: { title: string; rows: number }) {
  return (
    <section aria-busy="true">
      <h2>{title}</h2>
      <dl>
        {Array.from({ length: rows }, (_, i) => (
          <div key={i}>
            <dt>&nbsp;</dt>
            <dd>&nbsp;</dd>
          </div>
        ))}
      </dl>
    </section>
  )
}

// Cached, so it resolves during the prerender and needs no boundary.
export async function Summary() {
  const s = await getSummary()
  return (
    <header>
      <h1>Weekly report — {s.week}</h1>
      <p>
        {formatPrice(s.totalCents)} across {s.orders.toLocaleString('en-US')} orders
      </p>
    </header>
  )
}

export async function RevenuePanel() {
  return <Panel title="Revenue" rows={await getRevenue()} />
}

export async function TrafficPanel() {
  return <Panel title="Traffic" rows={await getTraffic()} />
}

export async function ErrorsPanel() {
  return <Panel title="Errors" rows={await getErrors()} />
}
