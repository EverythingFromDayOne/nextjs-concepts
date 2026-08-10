# Cursor — session 5: article 5 demo sources (`rendering/static-shell-and-streaming`)

First `.tpl`-native article. You receive the template and its demo sources together; there is no conversion step.

**Order:** write sources (§1–§4) → build → run the observation pass (§5) → place the template → `build-article.py` → gates. The observation pass is batched deliberately — that is where session 4's hour went.

---

## 1. Extend `lib/db.ts`

Append to the existing file. Latencies are widely separated so streaming order is observable rather than inferred.

```ts
export type ReportSummary = { week: string; totalCents: number; orders: number }
export type Row = { label: string; value: string }

const SUMMARY: ReportSummary = { week: '2026-W32', totalCents: 4_812_900, orders: 1_284 }

export const report = {
  // cached by lib/report.ts — resolves during the prerender
  summary: () => after(150, SUMMARY),
  // uncached, deliberately, and deliberately at three different speeds
  revenue: () => after(200, [
    { label: 'Subscriptions', value: '$28,140' },
    { label: 'One-off', value: '$14,220' },
    { label: 'Refunds', value: '-$1,431' },
  ] satisfies Row[]),
  traffic: () => after(600, [
    { label: 'Sessions', value: '84,201' },
    { label: 'Signups', value: '1,905' },
    { label: 'Bounce', value: '41%' },
    { label: 'Median TTFB', value: '180ms' },
  ] satisfies Row[]),
  errors: () => after(1500, [
    { label: '5xx', value: '12' },
    { label: '4xx', value: '3,904' },
  ] satisfies Row[]),
}
```

Add `report` to the exported `db` object.

## 2. `lib/report.ts`

```ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

export async function getSummary() {
  'use cache'
  cacheLife('hours')
  cacheTag('report:summary')
  return db.report.summary()
}

// No 'use cache' on the three below. Uncached I/O aborts the prerender,
// which is what makes each of them a hole rather than shell.
export async function getRevenue() {
  return db.report.revenue()
}

export async function getTraffic() {
  return db.report.traffic()
}

export async function getErrors() {
  return db.report.errors()
}
```

## 3. `app/streaming/` — fine-grained boundaries

**`app/streaming/panels.tsx`**

```tsx
import type { Row } from '@/lib/db'
import { getSummary, getRevenue, getTraffic, getErrors } from '@/lib/report'
import { formatPrice } from '@/lib/db'

function Panel({ title, rows }: { title: string; rows: Row[] }) {
  return (
    <section>
      <h2>{title}</h2>
      <dl>
        {rows.map((r) => (
          <div key={r.label}><dt>{r.label}</dt><dd>{r.value}</dd></div>
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
          <div key={i}><dt>&nbsp;</dt><dd>&nbsp;</dd></div>
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
      <p>{formatPrice(s.totalCents)} across {s.orders.toLocaleString('en-US')} orders</p>
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
```

**`app/streaming/page.tsx`**

```tsx
import { Suspense } from 'react'
import {
  Summary, RevenuePanel, TrafficPanel, ErrorsPanel, PanelSkeleton,
} from './panels'

/**
 * Three sibling boundaries, one per panel. Each resolves independently, so
 * the 1500ms panel never delays the 200ms one. <Summary /> sits outside any
 * boundary because it is cached — cached work resolves during the prerender
 * and therefore does not need a hole.
 */
export default function StreamingPage() {
  return (
    <main>
      <Summary />

      <Suspense fallback={<PanelSkeleton title="Revenue" rows={3} />}>
        <RevenuePanel />
      </Suspense>

      <Suspense fallback={<PanelSkeleton title="Traffic" rows={4} />}>
        <TrafficPanel />
      </Suspense>

      <Suspense fallback={<PanelSkeleton title="Errors" rows={2} />}>
        <ErrorsPanel />
      </Suspense>
    </main>
  )
}
```

## 4. `app/streaming-coarse/` — one boundary, same content

**`app/streaming-coarse/page.tsx`**

```tsx
import { Suspense } from 'react'
import {
  Summary, RevenuePanel, TrafficPanel, ErrorsPanel, PanelSkeleton,
} from '../streaming/panels'

/**
 * Identical data, identical latencies, one boundary instead of three.
 *
 * Two costs are predicted, and §5 measures both: nothing appears until the
 * slowest child resolves, and the cached <Summary /> is dragged out of the
 * shell because it now sits inside a hole.
 */
export default function CoarseStreamingPage() {
  return (
    <main>
      <Suspense fallback={<PanelSkeleton title="Weekly report" rows={4} />}>
        <Summary />
        <RevenuePanel />
        <TrafficPanel />
        <ErrorsPanel />
      </Suspense>
    </main>
  )
}
```

**`antipatterns/mismatched-fallback.tsx`** (tsconfig-excluded, extract-only)

```tsx
// antipattern: a centred spinner standing in for a four-row table. The
// shell reserves the wrong space, so the swap shifts the layout — which
// measures worse than having shown nothing. Extract-only; never compiled.
<Suspense fallback={<div className="spinner" />}>
  <TrafficPanel />
</Suspense>
```

## 5. Observation pass — run these together, capture to `observations/`

Batched on purpose. Every file below is extracted by the template.

```bash
pnpm --filter next-lab build
```

| Output file | How |
| --- | --- |
| `streaming-build-table.txt` | The build route table rows for `/streaming` and `/streaming-coarse` |
| `streaming-fine-shell.html.txt` | `.next/server/app/streaming.html` — trim to `<main>`…`</main>` |
| `streaming-coarse-shell.html.txt` | `.next/server/app/streaming-coarse.html` — same trim |
| `streaming-shell-diff.txt` | `diff` of the two above, or a hand-written 5-line summary of what differs if the raw diff is unreadable |
| `streaming-chunk-order.txt` | With the server running: `curl -N --raw -w '\n%{time_starttransfer} first byte\n%{time_total} total\n' http://localhost:PORT/streaming` — capture enough to show panels arriving in latency order, plus the timings |
| `streaming-coarse-timing.txt` | Same `curl -w` against `/streaming-coarse` — the total is the number that matters |

Every file's first line records the command, the date, and `next@16.3.0`.

### Two predictions to test — report mismatches, do not edit prose to fit

1. **`/streaming`'s shell contains the summary and all three skeletons.** `/streaming-coarse`'s shell contains only the one skeleton.
2. **The cached `<Summary />` is absent from `/streaming-coarse`'s prerendered HTML**, because a boundary that contains an aborting sibling becomes a hole, and the cached work inside it goes with it.

Prediction 2 is the article's central claim and I have not verified it. **If it is wrong, say so plainly** — the mechanism section is built on it and I would rather rewrite than ship it.

Also record: does `/streaming-coarse` still show `◐` in the build table despite having no useful shell, or is it annotated differently?

## 6. Then place the template

`docs/concepts/rendering/static-shell-and-streaming.md.tpl` ships alongside this. After the observation pass:

```bash
python3 scripts/build-article.py docs/concepts/rendering/static-shell-and-streaming.md.tpl
pnpm verify
```

Article ships at `status: draft` — the two predictions above must be confirmed before it moves to `review`.

---

## Acceptance

- [ ] `lib/db.ts` extended; `lib/report.ts`, both routes, and the antipattern written; build green
- [ ] All six observation files captured in one pass, each with a provenance first line
- [ ] Both predictions reported as confirmed or contradicted, **with the evidence**
- [ ] Template builds; every `{EXTRACT:}` resolves; gates green
- [ ] Report how long this took end to end — the `.tpl`-native workflow is on trial here, and the number decides whether the format survives 42 more articles
