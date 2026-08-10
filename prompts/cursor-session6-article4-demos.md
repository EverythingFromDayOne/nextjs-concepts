# Cursor — session 6: article 4 demos (`foundations/build-time-request-time-and-the-client`)

`.tpl`-native, second time. Sources → build → batched observation pass → template → gates.

**Four experiments in §5, three of which test claims I cannot currently support.** Experiment 3 in particular may change the article's structure. Report contradictions; do not adjust prose to fit.

Reused from session 3, no new capture needed: `observations/sync-io-error.txt`, `observations/insight-blocking-prerender.txt`, `app/products/[slug]/price-as-of.tsx`.

---

## 1. `lib/when.ts`

```ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

/**
 * Resolves during the prerender. Note what it cannot return: anything
 * derived from the moment it ran. A cached scope has no honest way to
 * report its own build time to a reader.
 */
export async function getStaticFacts() {
  'use cache'
  cacheLife('hours')
  cacheTag('facts')
  return db.report.summary()
}
```

## 2. `app/when/` — the three times, side by side

**`app/when/sections.tsx`**

```tsx
import { connection } from 'next/server'
import { getStaticFacts } from '@/lib/when'
import { formatPrice } from '@/lib/db'

/**
 * BUILD TIME. Cached, so it resolves during the prerender and lands in the
 * shell. It deliberately displays no timestamp — a value describing when
 * this ran would be baked into a static artifact and wrong for every
 * visitor after the first. That absence is the lesson.
 */
export async function BuildTimeSection() {
  const facts = await getStaticFacts()
  return (
    <section>
      <h2>Build time</h2>
      <p>{formatPrice(facts.totalCents)} — same for every visitor this hour.</p>
    </section>
  )
}

/**
 * REQUEST TIME. connection() is the explicit abort: "do not prerender past
 * this line." Only after it is new Date() legal, because only then does a
 * request exist for it to describe.
 */
export async function RequestTimeSection() {
  await connection()
  return (
    <section>
      <h2>Request time</h2>
      <p>Rendered at <time>{new Date().toISOString()}</time></p>
    </section>
  )
}
```

**`app/when/client-section.tsx`**

```tsx
'use client'

// client: reads a value that only exists in a browser
import { useEffect, useState } from 'react'

export function ClientTimeSection() {
  const [at, setAt] = useState<string | null>(null)

  // Runs after hydration, never on the server. The null first render is
  // what the server sends and what the client must agree with.
  useEffect(() => {
    setAt(new Date().toISOString())
  }, [])

  return (
    <section>
      <h2>Client time</h2>
      <p>{at ? <>Hydrated at <time>{at}</time></> : 'Not hydrated yet'}</p>
      <p>Viewport: {typeof window === 'undefined' ? 'unknown on the server' : `${window.innerWidth}px`}</p>
    </section>
  )
}
```

**`app/when/page.tsx`**

```tsx
import { Suspense } from 'react'
import { BuildTimeSection, RequestTimeSection } from './sections'
import { ClientTimeSection } from './client-section'

export default function WhenPage() {
  return (
    <main>
      <BuildTimeSection />

      <Suspense fallback={<p aria-busy="true">Waiting for a request…</p>}>
        <RequestTimeSection />
      </Suspense>

      <ClientTimeSection />
    </main>
  )
}
```

## 3. `app/after-demo/` — the fourth time

**`lib/audit.ts`**

```ts
export async function recordView(route: string, at: number) {
  // Stands in for an analytics write or an audit-log insert: work the
  // visitor must never wait for.
  await new Promise((r) => setTimeout(r, 300))
  console.log(`[audit] ${route} viewed, queued at ${at}, written at ${Date.now()}`)
}
```

**`app/after-demo/page.tsx`**

```tsx
import { after, connection } from 'next/server'
import { recordView } from '@/lib/audit'

export default async function AfterDemoPage() {
  await connection()
  const queuedAt = Date.now()

  // Scheduled now, executed after the response has been sent. The 300ms
  // write does not appear in the visitor's total.
  after(() => recordView('/after-demo', queuedAt))

  console.log(`[render] /after-demo responded at ${Date.now()}`)

  return <main><h1>Response sent; audit still pending.</h1></main>
}
```

## 4. Antipatterns (tsconfig-excluded, extract-only)

**`antipatterns/sync-io-variants.tsx`**

```tsx
// antipattern: four values that cannot suspend. Each would be computed once
// during the prerender and served to every visitor for the life of the
// deployment. Extract-only; never compiled.
export function Variants() {
  const a = new Date()               // build-time clock, frozen
  const b = Date.now()               // same, as a number
  const c = Math.random()            // one "random" value for everyone
  const d = crypto.randomUUID()      // one "unique" id for everyone
  return <pre>{String([a, b, c, d])}</pre>
}
```

**`antipatterns/instant-false-doesnt-help.tsx`**

```tsx
// antipattern: instant = false permits a segment to BLOCK. It says nothing
// about whether a value can be computed ahead of a request. A latency
// opt-out cannot resolve a correctness failure. Extract-only.
export const instant = false

export default function Page() {
  return <time>{new Date().toISOString()}</time>
}
```

## 5. Experiments — batched observation pass

Run all of these in one sitting and capture to `observations/`. Every file's first line records command, date, and `next@16.3.0`.

### Experiment 1 — do all four sync-IO primitives error identically?

Temporarily add each of `new Date()`, `Date.now()`, `Math.random()`, `crypto.randomUUID()` to a scratch route outside any `<Suspense>` and outside any cached scope. Build after each. **Remove the scratch route afterwards.**

→ `observations/sync-io-variants.txt` — the four error messages, or a note that some produce no error at all.

**This may not come out clean.** If Next only catches some of them, that is a much more important finding than if it catches all four, and the article needs to say which are guarded and which will simply ship wrong.

### Experiment 2 — does `instant = false` clear a sync-IO error?

Scratch route with both `export const instant = false` and a bare `new Date()`. Build.

→ `observations/instant-false-syncio.txt`

I claim it does not help. Verify. Remove the route afterwards.

### Experiment 3 — is `new Date()` legal inside a `'use cache'` scope?

**The one I am least sure about.** A cache entry arguably has an honest creation time, so this could be permitted; or it could error because the entry outlives the moment it describes.

```ts
export async function getStamped() {
  'use cache'
  cacheLife('minutes')
  return { at: new Date().toISOString(), data: await db.report.summary() }
}
```

Wire it to a scratch route and build. → `observations/date-in-cache-scope.txt`

Record all three of: does it build, does it run, and — if it runs — **does the timestamp change between two requests inside the cache lifetime, or is it frozen at the entry's creation?** The third question is the interesting one and it needs two `curl`s a few seconds apart.

If this is *permitted*, the article gains a section: a cached timestamp is legal, frozen, and a trap for anyone reading it as "now." If it *errors*, the sync-IO rule is simpler than I have written it. Either outcome changes the prose.

### Experiment 4 — when does `after()` actually run?

```bash
pnpm start
curl -w '\n%{time_total} response complete\n' http://localhost:PORT/after-demo
```

→ `observations/after-ordering.txt` — the `curl` timing plus the two server log lines, so the `[render]` / response-complete / `[audit]` ordering is visible.

The claim under test: the 300ms audit write does not appear in the visitor's total.

---

## 6. Template

`docs/concepts/foundations/build-time-request-time-and-the-client.md.tpl` ships alongside. After the observation pass:

```bash
python3 scripts/build-article.py docs/concepts/foundations/build-time-request-time-and-the-client.md.tpl
pnpm verify
```

Ships at `status: draft`; experiments 1–4 must be reported before it moves to `review`.

---

## Acceptance

- [ ] Sources written; `/when` and `/after-demo` build and are reachable
- [ ] Four observation files captured; all scratch routes removed afterwards
- [ ] Experiment 1 reports per-primitive results, not a summary — name any primitive that is *not* caught
- [ ] Experiment 3 answers all three questions, including the two-request timestamp check
- [ ] Template builds; gates green
- [ ] Time end to end, for comparison against session 5's 15–20 minutes
