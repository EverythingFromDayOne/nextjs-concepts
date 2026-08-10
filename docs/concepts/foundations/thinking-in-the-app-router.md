---
article_id: thinking-in-the-app-router
concept_folder: foundations
wave: 1
related:
  - foundations/server-and-client-components
  - rendering/static-shell-and-streaming
  - caching/cache-components-model
  - foundations/build-time-request-time-and-the-client
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-09
status: draft
---

# Thinking in the App Router

> **Lead with this.** A route is not static or dynamic. A route is a **static shell with holes**, and every piece of data in your app answers exactly one of four questions: **cache it**, **stream it**, **block on it**, or **push it to the client**. Once you can look at a page and say which answer each piece gets, the rest of Next.js is mechanics.

This is the anchor article. Every other article in this repository assumes the model below.

---

## What it is

Under Cache Components, Next.js renders a route in two conceptually separate passes.

The **prerender pass** happens ahead of the request — at build, or in the background afterwards. It has no request. There are no cookies, no headers, no search params, no client IP. It runs your component tree and keeps everything it can compute without a request. The result is the **static shell**: real HTML, ready to serve to the first byte of any request.

The **request pass** happens per request. It fills in the parts the prerender pass couldn't compute, and streams them into the shell that was already sent.

The seam between those two passes is not a route-level setting. It is a `<Suspense>` boundary. Everything above the boundary is shell; everything below it is a hole the request pass fills.

That single sentence is the whole model:

```
shell  = everything computable without a request
hole   = a <Suspense> boundary containing work that needs the request
'use cache' = "this needs I/O, but the result is reusable, so put it in the shell anyway"
```

And so the four answers:

| Answer | Mechanism | When |
| --- | --- | --- |
| **Cache it** | `'use cache'` (+ `cacheLife`, `cacheTag`) | The value is the same for many requests. Blog posts, product catalogs, nav menus, pricing tables. |
| **Stream it** | `<Suspense>` | The value differs per request and the user can look at something else meanwhile. Inventory counts, personalization, feeds. |
| **Block on it** | `export const instant = false` | The page is meaningless without it and a shell would be a lie. A permalink whose entire content is the data. |
| **Push it to the client** | `'use client'` + fetch after hydration | The value is device-local or changes on interaction. Theme, geolocation, live sockets. |

You will pick wrong sometimes. That is fine — Next.js validates the choice in development and tells you when a route can't produce a shell. What it cannot do is pick for you, and the previous version of the framework's attempt to pick for you is exactly what this model replaced.

---

## How it works under the hood

### The prerender pass aborts; it does not lie

The interesting design decision is what happens when the prerender pass hits `cookies()`.

It does not return `undefined`. It does not return an empty store. It **aborts the subtree**. The abort propagates upward until it reaches a `<Suspense>` boundary, and that boundary becomes a hole — the prerender pass emits the fallback into the shell and marks the position for the request pass to fill.

This is why the fix for "reading cookies made my whole route dynamic" is never a config flag. It is *moving the read below a boundary*:

```tsx
// The read is at the top of the page. The abort propagates to the root.
// There is no boundary to stop at, so there is no shell.
export default async function Page() {
  const theme = (await cookies()).get('theme')?.value
  return <Dashboard theme={theme} />
}
```

```tsx
// The read is below a boundary. The abort stops there.
// Everything outside <Suspense> prerenders into the shell.
export default function Page() {
  return (
    <>
      <DashboardChrome />
      <Suspense fallback={<DashboardSkeleton />}>
        <PersonalizedDashboard />
      </Suspense>
    </>
  )
}

async function PersonalizedDashboard() {
  const theme = (await cookies()).get('theme')?.value
  // ...
}
```

Nothing about the *amount* of dynamic work changed between those two files. What changed is how much of the tree the abort can reach.

The same mechanic explains a rule that otherwise looks arbitrary: `params` and `searchParams` are promises, and you await them **inside** the boundary rather than at the top of the page. Awaiting at the top puts the abort above every boundary you have.

### Synchronous IO is the exception, and the exception is the proof

`cookies()` can abort because it is awaited — there is a suspension point to hang the abort on.

`new Date()`, `Date.now()`, `Math.random()`, and `crypto.randomUUID()` have no suspension point. They return immediately. If the prerender pass let them through, it would bake a build-time timestamp or a build-time random number into a static artifact and serve it to every user for the lifetime of the deployment. That is a silent, permanent wrong answer.

So Next.js does the only safe thing: it fails the prerender with a build error.

This is why `instant = false` does not clear those errors, and the distinction is worth internalizing:

- `instant = false` means *"this segment is allowed to block."* It is a statement about latency.
- A synchronous-IO error means *"this value cannot be computed ahead of the request at all."* It is a statement about correctness.

A latency opt-out cannot resolve a correctness problem. The fix is to move the call to where a request exists — inside a `<Suspense>` boundary, after `await connection()` — or into a Client Component where it runs on the user's machine.

```tsx
import { connection } from 'next/server'

async function ServerClock() {
  await connection() // "I need a real request; do not prerender past this line"
  return <time>{new Date().toISOString()}</time>
}
```

`connection()` is the explicit form of what `cookies()` does implicitly. Note the corollary: it is prohibited inside `'use cache'` and `'use cache: private'` scopes, because a cache entry that depends on the connection is a cache entry with no reuse.

### `'use cache'` moves work back into the shell

If `<Suspense>` says "this can't be in the shell," `'use cache'` says "this can, despite doing I/O."

```tsx
import { cacheLife, cacheTag } from 'next/cache'

export async function getProduct(slug: string) {
  'use cache'
  cacheLife('hours')
  cacheTag(`product:${slug}`)
  return db.query.products.findFirst({ where: eq(products.slug, slug) })
}
```

The cache key is derived by the compiler rather than written by you. It is built from the build ID and the serialized arguments. **Anything read from ambient state at execution time cannot be in the key** — and the framework can only stop you when that ambient state is a Next API it recognizes.

Two consequences fall directly out of that:

1. **The key contains the arguments, not the ambient request.** A cached function has no idea who is asking. `cookies()` inside the scope throws at request time — but a module-level variable set by the caller, or an argument that is the same for every signed-in user, will not. If user-specific data reaches a `'use cache'` scope without being an *identifying* argument, you have built a cross-user leak. This is the single most dangerous failure mode in the model and it has its own recipe.
2. **The build ID is in the key, so every deploy invalidates every entry.** `'use cache'` also defaults to in-memory storage, so entries do not survive instance teardown either. The old `fetch` Data Cache and `unstable_cache` persisted across deploys; this does not, unless you reach for `'use cache: remote'` or a cache handler. Teams migrating from 15 hit this as a cold-start cost spike, not as a bug report.

### What the client does with the shell

The shell is not only a server-side artifact. It is the unit of prefetching.

When a `<Link>` prefetches, it pulls the target route's shell. On click, the router renders that shell immediately — no network wait — and streams the holes in behind it. This is why "make the shell as large as honestly possible" is a performance strategy and not just an aesthetic preference: the shell *is* the instant part of the navigation.

Before 16.3, the only reusable prefetchable shell was a `loading.tsx` file, so forgetting one meant a blocking navigation with no warning. 16.3 extracts shells from any route's tree and adds **Instant Insights** in DevTools to surface navigations that aren't instant, so the failure is visible instead of silent.

One further behavior worth knowing before you meet it as a bug: navigating away no longer unmounts the previous route. Next.js keeps it alive via React's `<Activity>` component in `hidden` mode. Effects still clean up and re-run, but `useState`, form inputs, and scroll position survive a round trip. Code that relied on unmounting to reset state now needs to reset explicitly.

---

## Basic usage

Two files. This is the entire opt-in.

```ts
// next.config.ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
}

export default nextConfig
```

```tsx
// app/page.tsx
import { Suspense } from 'react'
import { cacheLife } from 'next/cache'
import { cookies } from 'next/headers'

export default function Page() {
  return (
    <main>
      <Headline />                        {/* shell: cached I/O */}
      <Suspense fallback={<GreetingSkeleton />}>
        <Greeting />                      {/* hole: needs the request */}
      </Suspense>
    </main>
  )
}

async function Headline() {
  'use cache'
  cacheLife('hours')
  const { title } = await getSiteConfig()
  return <h1>{title}</h1>
}

async function Greeting() {
  const name = (await cookies()).get('name')?.value ?? 'there'
  return <p>Hello, {name}.</p>
}
```

Run `next build` and read the output: the route is prerendered, and the shell contains the headline and the skeleton. Run `next start`, load the page, and the greeting streams in.

Do **not** evaluate caching behavior in `next dev`. Dev deliberately behaves differently — prefetching is disabled, and cache entries do not behave as they will in production. Every caching claim in this repository is verified with `next build && next start`.

---

## Walkthrough — one product page, all four answers

We will build a single route that uses every one of the four answers, because that is the fastest way to make the model concrete. A product detail page with:

- a **catalog record** that is the same for everyone → *cache it*
- a **live inventory count** that must be current → *stream it*
- a **recently-viewed strip** read from a cookie → *stream it*
- a **"prices as of" timestamp** → *stream it, after `connection()`*
- an **add-to-cart button** with local UI state → *push it to the client*

### Step 1 — the cached data access

```ts
// lib/catalog.ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from '@/lib/db'
import { products } from '@/lib/schema'
import { eq } from 'drizzle-orm'

export async function getProduct(slug: string) {
  'use cache'
  cacheLife('hours')
  cacheTag(`product:${slug}`)

  return db.query.products.findFirst({
    where: eq(products.slug, slug),
  })
}
```

Three things are load-bearing here and none of them are the directive itself:

- `slug` is an **argument**, so it is in the compiler-derived key. One entry per product, which is what you want.
- `cacheTag` gives the write side a handle. When an admin edits this product, `updateTag('product:' + slug)` from the Server Action expires exactly this entry.
- `cacheLife('hours')` is a ceiling, not a promise. Tag invalidation still wins.

### Step 2 — the page: shell first, holes explicit

```tsx
// app/products/[slug]/page.tsx
import { Suspense } from 'react'
import { getProduct } from '@/lib/catalog'
import { AddToCart } from './add-to-cart'
import { Inventory, InventorySkeleton } from './inventory'
import { RecentlyViewed, RecentlyViewedSkeleton } from './recently-viewed'
import { PriceAsOf } from './price-as-of'

export default function Page({ params }: PageProps<'/products/[slug]'>) {
  return (
    <main>
      <Suspense fallback={<ProductHeaderSkeleton />}>
        <ProductHeader params={params} />
      </Suspense>

      <Suspense fallback={<InventorySkeleton />}>
        <Inventory params={params} />
      </Suspense>

      <Suspense fallback={null}>
        <PriceAsOf />
      </Suspense>

      <Suspense fallback={<RecentlyViewedSkeleton />}>
        <RecentlyViewed />
      </Suspense>
    </main>
  )
}

async function ProductHeader({
  params,
}: Pick<PageProps<'/products/[slug]'>, 'params'>) {
  const { slug } = await params
  const product = await getProduct(slug)
  if (!product) notFound()

  return (
    <header>
      <h1>{product.name}</h1>
      <p>{product.description}</p>
      <strong>{formatPrice(product.priceCents)}</strong>
      <AddToCart productId={product.id} />
    </header>
  )
}
```

Note what the page component itself is: a **layout of boundaries**. It is not `async`. It awaits nothing. Its entire job is to declare where the shell ends.

`params` is passed down as a promise rather than awaited here. If we awaited it in `Page`, the abort would sit above every boundary and there would be no shell for any product whose slug wasn't prerendered by `generateStaticParams`.

### Step 3 — the streamed holes

```tsx
// app/products/[slug]/inventory.tsx
import { getLiveStock } from '@/lib/inventory'

export async function Inventory({
  params,
}: Pick<PageProps<'/products/[slug]'>, 'params'>) {
  const { slug } = await params
  const stock = await getLiveStock(slug) // deliberately uncached

  return stock > 0
    ? <p>{stock} in stock</p>
    : <p>Out of stock</p>
}

export function InventorySkeleton() {
  return <p aria-busy="true">Checking inventory…</p>
}
```

`getLiveStock` has no `'use cache'`. That is not an omission — it is the decision. Inventory that is thirty seconds stale sells things you do not have.

```tsx
// app/products/[slug]/recently-viewed.tsx
import { cookies } from 'next/headers'
import { getProductsByIds } from '@/lib/catalog'

export async function RecentlyViewed() {
  const raw = (await cookies()).get('recently-viewed')?.value
  const ids = raw ? (JSON.parse(raw) as string[]) : []
  if (ids.length === 0) return null

  const products = await getProductsByIds(ids)
  return (
    <section>
      <h2>Recently viewed</h2>
      <ul>{products.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
    </section>
  )
}
```

The cookie read happens **here**, in the uncached component, and the ids are handed to `getProductsByIds` as an argument. The lookup itself can be cached; the *knowledge of who is asking* cannot be. Getting this boundary backwards — reading the cookie inside the cached function — is how the cross-user leak happens.

```tsx
// app/products/[slug]/price-as-of.tsx
import { connection } from 'next/server'

export async function PriceAsOf() {
  await connection()
  return (
    <p>
      Prices as of <time>{new Date().toLocaleTimeString()}</time>
    </p>
  )
}
```

Without `await connection()`, this file fails the build. Measured on `next@16.3.0`:

```
Error: Route "/products/[slug]": Next.js encountered the unstable value new Date() while prerendering.
```

The error's own fix list includes `await connection()`. Synchronous IO cannot abort, so Next.js refuses to bake a build-time clock into the shell.

### Step 4 — the client leaf

```tsx
// app/products/[slug]/add-to-cart.tsx
'use client'

import { useState } from 'react'
import { addToCart } from './actions'

export function AddToCart({ productId }: { productId: string }) {
  const [qty, setQty] = useState(1)

  return (
    <form action={addToCart}>
      <input type="hidden" name="productId" value={productId} />
      <input
        type="number"
        name="qty"
        min={1}
        value={qty}
        onChange={(e) => setQty(Number(e.target.value))}
      />
      <button type="submit">Add to cart</button>
    </form>
  )
}
```

`'use client'` sits on the **leaf**, not on the page. The header around it stays a Server Component and stays in the shell. This is the shape to internalize: the client boundary is pushed as far down the tree as it will go.

### Step 5 — verify the loop

```bash
pnpm build      # read the output: is /products/[slug] prerendered?
pnpm start
```

Then, in order:

1. After `pnpm build`, open `.next/server/app/products/aeron-chair.html`. The name, price, and description should be in that prerender artifact — not inferred from a `curl` body or DevTools.
2. Confirm "Checking inventory…" is the inventory hole in that same file (or absent from the static HTML while the product header is present). The real count arrives in the stream; `curl` will show both.
3. Load a slug that `generateStaticParams` did not return (`keyboard-tray`). You should still get a shell, then the content.
4. Delete the `recently-viewed` cookie and reload. The section disappears; the rest of the page is unchanged.
5. Comment out `await connection()` in `price-as-of.tsx` and rebuild. The build fails with:
   `Error: Route "/products/[slug]": Next.js encountered the unstable value new Date() while prerendering.`
   The error's own fix list includes `await connection()` — that failure is the model protecting you.

Step 5 is the one people skip and the one that makes the mechanism stick.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 1, 2, 7, 8, 9, 19.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Default caching posture | Cached unless you opted out | Dynamic unless you opt in | Caching moved from a **route classification resolved during build planning** to **per-scope cache entries with compiler-derived keys**. There is no longer a single answer per route to classify. |
| What "dynamic" describes | The whole route | A boundary inside the route | One render pass per route became **two passes** — prerender and request — with `<Suspense>` marking the seam between them. "Dynamic" is now a property of the subtree below a boundary. |
| Cost of reading `cookies()` | De-opted the entire route to request-time rendering | De-opts only up to the nearest boundary | Runtime APIs went from **setting a flag the planner reads** to **aborting the prerender at their call site**. Abort propagation, not flag inspection, is what determines the blast radius. |
| Opting a route out of caching | `export const dynamic = 'force-dynamic'` | Nothing to write; delete it | The opt-out disappeared because the thing it opted out of no longer exists. Keeping the export is now a build error, not a no-op. |
| Cache lifetime | `export const revalidate = 3600` on the segment | `cacheLife('hours')` inside a cached scope | A **whole-route declaration** became a **profile attached to one cache entry**. One route can now hold many entries with different lifetimes, which the segment config could not express. |
| Cache keys | Written by hand: `unstable_cache(fn, ['user', id], …)` | Derived by the compiler from the build ID and serialized arguments | Key correctness moved from **your discipline** to **the compiler's analysis** — which removes a class of stale-key bugs and introduces a new one: anything read from ambient state at execution time cannot be in the key, and the framework can only stop you when that ambient state is a Next API it recognizes. |
| Prefetchable loading state | One `loading.tsx` per route, or nothing | A shell extracted from any route's tree | The prefetch payload went from **a file you remembered to write** to **an artifact derived from your boundary placement**, with Instant Insights surfacing routes that produce nothing useful. |
| Navigating away | The route unmounted; state was discarded | `<Activity>` keeps it in `hidden` mode | The router stopped destroying the previous tree, so state persistence became the default and resetting became the explicit act. |

---

## Real-world patterns

**Design the shell first.** Before writing a component, ask what a user should see 50ms after clicking, with zero data. That answer *is* your shell. Boundaries then go wherever that picture ends.

**Boundaries belong at the smallest honest unit.** A boundary around the whole page and a boundary around the one personalized widget produce the same correctness and wildly different experiences. Push each boundary down until the thing above it is genuinely computable without a request.

**Watch the shared layout.** A single `cookies()` read in a header component that lives in the root layout de-opts every route beneath it. Layout-level runtime reads are the highest-leverage mistake in the entire model, because the blast radius is the whole app. When the value must drive an attribute on `<html>` — theme, `lang`, `dir` — there is no child to wrap, and the pattern is an inline script in `<head>` that sets the attribute before paint.

**Fallbacks are shells, not spinners.** A fallback that doesn't match the eventual layout produces a visible shift, which reads as *slower* than no shell at all. Match the shape: same heights, same slots, no centered spinner where a table will be.

**Cache the lookup, not the identity.** The reusable half of personalized data is almost always a lookup keyed by an id. Read the identity outside the cached scope, pass the id in. Keeping that split habitual is what prevents the leak class.

**Verify with a build, then defend with a test.** `@next/playwright` ships an `instant()` helper that asserts what is visible during a navigation *without waiting for the network*. That turns "this page feels instant" into a regression gate — a genuinely new category of test, and the only defense against a shared component quietly de-opting a route six months from now.

---

## API and type reference

| Surface | Import | Role in the model |
| --- | --- | --- |
| `cacheComponents: true` | `next.config.ts` | Enables the whole model. Requires the Node.js runtime. |
| `partialPrefetching: true` | `next.config.ts` | Extracts reusable shells from any route for prefetching. |
| `'use cache'` | directive | Marks a file, component, or async function as reusable. Must be `async`. |
| `'use cache: remote'` | directive | Same, with durable storage via a cache handler. Network round-trip. |
| `'use cache: private'` | directive | **Experimental.** Permits runtime APIs in a cached scope; browser-memory only, never stored on the server. |
| `cacheLife(profile)` | `next/cache` | Lifetime profile for the enclosing cached scope. |
| `cacheTag(tag)` | `next/cache` | Invalidation handle for the enclosing cached scope. |
| `connection()` | `next/server` | "Do not prerender past this line." Prohibited inside `'use cache'` and `'use cache: private'`. |
| `<Suspense>` | `react` | Defines the shell/hole seam. |
| `export const instant = false` | route segment config | Marks a segment as allowed to block. Does **not** force dynamic; does **not** clear synchronous-IO errors. |
| `after(fn)` | `next/server` | Work that runs after the response is sent. |

---

## Common mistakes

**1. Putting `'use cache'` at the top of the page to "make it fast."**

```tsx
// Wrong: now every runtime read below this is illegal,
// and the page is one coarse cache entry keyed by almost nothing.
export default async function Page() {
  'use cache'
  // ...
}
```
Cache the data access, not the route. Start at the leaf and move up only if there is a measured reason.

**2. Awaiting `params` or `searchParams` at the top of a page.** The abort lands above every boundary and there is no shell for any un-prerendered path. Pass the promise down and await it inside `<Suspense>`.

**3. Reading `cookies()` or `headers()` in a shared layout.** One line, whole-app blast radius. If the value is genuinely global, an inline script that sets it before paint keeps the shell intact.

**4. Reaching for `instant = false` when the error is synchronous IO.** It won't clear it, and the attempt usually means the mechanism hasn't landed yet. Latency opt-outs don't fix correctness errors.

**5. Evaluating caching in `next dev`.** Dev disables prefetching and behaves differently around cache entries. Every caching conclusion needs `next build && next start`.

**6. Assuming `'use cache'` entries survive a deploy.** The build ID is in the key and the default store is in-memory. Migrating from `unstable_cache` or the `fetch` Data Cache, both of which persisted, this shows up as a cold-cache cost spike right after every release.

**7. Assuming the framework will catch identity in a cached scope.**

```tsx
// Wrong: no Next API is touched, so nothing throws —
// and lastSeenUid is read at execution time, so it is not in the key.
let lastSeenUid = 'anonymous'

async function getDashboard() {
  'use cache'
  return db.dashboardFor(lastSeenUid)
}
```

`cookies()` inside the scope *does* throw — at request time, not build time. Ambient module state and coarse arguments do not. Read outside, pass in an argument that **identifies** the data. Then check authorization outside every cached scope as well — a cache hit must never be a way to skip a permission check.

**8. `useSearchParams` in a Client Component without a boundary.** Search params are only known at request time, so the hook always suspends during prerendering, wherever it sits in the tree. Wrap the smallest component that reads it.

**9. Copying `export const dynamic = 'force-dynamic'` from a tutorial.** Under `cacheComponents` this is a build error rather than a no-op — which is a mercy. The silent version of this mistake is copying a pre-16 fetch-caching idiom that still *compiles* and now means the opposite thing.

**10. Treating a Server Component re-render like a React re-render.** It is a server round trip that returns a new payload, not a local function call. Anything you would have solved with a cheap re-render needs to be solved with a client boundary or a cache entry.

---

## Exercises

**1. Find the shell.** Take any route in an app you already have and, without changing code, write down which parts a user could see with no request. Then count the `<Suspense>` boundaries. If the two lists disagree, you have found your first misplaced boundary.

*Hint: the parts that survive are exactly the parts that don't await anything request-shaped.*

**2. Break it on purpose.** In the walkthrough app, move `await params` from `ProductHeader` up into `Page`. Build. Read the error carefully — it is describing abort propagation. Then move it back.

*Hint: compare the build output for `/products/[slug]` before and after. The route's prerender status is the tell.*

**3. Classify a real page.** Take a page with at least five distinct pieces of data — a dashboard is ideal — and assign each one of the four answers. For every "stream it," name what the user looks at instead while it loads. For every "cache it," name the tag that invalidates it and the write that fires that tag.

*Hint: if you can't name the invalidating write, the answer is probably "stream it," not "cache it."*

---

## Summary

- A route is a **static shell with holes**, produced by two passes: prerender and request.
- `<Suspense>` marks the seam. `'use cache'` moves work back across it into the shell.
- Runtime APIs **abort** the prerender at their call site; the abort propagates to the nearest boundary. That propagation, not a config flag, determines the blast radius.
- Synchronous IO cannot abort, so it is a hard build error that no opt-out clears.
- Cache keys are compiler-derived from the build ID and the serialized arguments. Anything read from ambient state at execution time cannot be in the key — and the framework can only stop you when that ambient state is a Next API it recognizes.
- The shell is the unit of prefetching, so shell size is a navigation-performance decision.
- Every piece of data gets one of four answers: cache, stream, block, or push to the client.

---

## See also

- [`foundations/server-and-client-components`](./server-and-client-components.md) — where the client boundary goes and what may cross it
- [`rendering/static-shell-and-streaming`](../rendering/static-shell-and-streaming.md) — the shell/hole mechanics in depth
- [`caching/cache-components-model`](../caching/cache-components-model.md) — why the default inverted, and the four-way decision in full
- [`caching/use-cache-directive`](../caching/use-cache-directive.md) — what actually goes into a compiler-derived key
- [`data/runtime-data-and-cached-scopes`](../data/runtime-data-and-cached-scopes.md) — the read-outside-pass-in rule and its failure mode
- [`reactjs-concepts` → `rendering/how-react-renders`](../../../reactjs-concepts/docs/concepts/rendering/how-react-renders.md) — render and commit, if the React side is unfamiliar

---

## References

- Next.js — `next.config.js: cacheComponents`
- Next.js — Getting Started: Caching
- Next.js — Directives: `use cache`, `use cache: remote`, `use cache: private`
- Next.js — Guides: Migrating to Cache Components
- Next.js — Guides: Instant Navigation
- Next.js — Functions: `connection`, `cacheLife`, `cacheTag`
- Next.js blog — Next.js 16.3 (2026-08-03)
- React — `<Suspense>`, `<Activity>`

---

## Demo source

`demos/next-lab/app/products/[slug]/` and `demos/next-lab/lib/catalog.ts`.

> **Verification status.** Version facts in this article were verified on 2026-08-09 against the npm registry (`next@16.3.0` is `latest`; `react@19.2.8`; `typescript@7.0.2`; `@next/playwright@16.3.0`) and against official Next.js documentation and the 16.3 release post; demo measurements 2026-08-10. **Measured:** sync-IO build error quotes `unstable value new Date() while prerendering` on `/products/[slug]` (fix list includes `await connection()`); route table shows `◐` PPR for that segment. Pending: whether `notFound()` inside a `<Suspense>`-wrapped child behaves identically to the page-level call under `catchError`. Code blocks are **authored, not yet extracted** — replace via `scripts/build-article.py` before promoting out of `draft`.
