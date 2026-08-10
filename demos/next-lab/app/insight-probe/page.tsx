import { cookies } from 'next/headers'
import { db } from '@/lib/db'

/**
 * Insight probe.
 *
 * Measured 2026-08-10 on next@16.3.0 (`next dev`, port 3010):
 * With root-level `cookies()` + uncached `db.usage.forUser` and *without*
 * `instant = false`, the route returned HTTP 200 while the dev-server log
 * printed:
 *
 *   Error: Route "/insight-probe": Next.js encountered uncached data during
 *   prerendering. … Learn more: …/blocking-prerender-dynamic
 *
 * That message is the validation surface docs call an "insight" — it is not
 * in the HTML body. Overlay / DevTools MCP not separately confirmed.
 *
 * `instant = false` is set so `next build` stays green; remove it locally to
 * re-trigger the log line.
 */
export const instant = false

export default async function InsightProbePage() {
  const uid = (await cookies()).get('uid')?.value ?? 'anonymous'
  const usage = await db.usage.forUser(uid)

  return (
    <main>
      <h1>Insight probe</h1>
      <p data-uid={uid}>requests={usage.requests}</p>
    </main>
  )
}
