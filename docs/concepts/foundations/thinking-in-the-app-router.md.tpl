---
article_id: thinking-in-the-app-router
concept_folder: foundations
wave: 1
related:
  - foundations/server-and-client-components
  - rendering/static-shell-and-streaming
  - caching/cache-components-model
  - foundations/rules-of-the-server-boundary
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-11
status: draft
---

# Thinking in the App Router

> **Lead with this.** A route is not static or dynamic. A route is a **static shell with holes**, and every piece of data in your app answers exactly one of four questions: **cache it**, **stream it**, **block on it**, or **push it to the client**. Once you can look at a page and say which answer each piece gets, the rest of Next.js is mechanics.

This is the anchor article. Every other article in this repository assumes the model below.

---

## What it is

Under Cache Components, Next.js renders a route in two conceptually separate passes.

The **prerender pass** happens ahead of the request — at build, or in the background afterwards. It has no request. No cookies, no headers, no search params, no client IP. It runs your component tree and keeps everything it can compute without a request. The result is the **static shell**: real HTML, ready to serve as the first byte of any response.

The **request pass** happens per request. It fills in the parts the prerender pass couldn't compute, and streams them into the shell that was already sent.

The seam between those passes is not a route-level setting. It is a `<Suspense>` boundary. Everything above it is shell; everything below it is a hole the request pass fills.

```
shell        = everything computable without a request
hole         = a <Suspense> boundary containing work that needs the request
'use cache'  = "this needs I/O, but the result is reusable — put it in the shell anyway"
```

And so the four answers:

| Answer | Mechanism | When |
| --- | --- | --- |
| **Cache it** | `'use cache'` (+ `cacheLife`, `cacheTag`) | The value is the same across many requests, and you can name the write that invalidates it. |
| **Stream it** | `<Suspense>` | The value differs per request and the user can look at something else meanwhile. |
| **Block on it** | `export const instant = false` | The page is meaningless without it and a shell would be a lie. |
| **Push it to the client** | `'use client'` + fetch after hydration | The value doesn't exist on the server — device facts, high-frequency interaction, live connections. |

The useful tie-breaker: **if you cannot name the write that invalidates it, the answer is "stream it," not "cache it."** Most stale-data bugs are a "cache it" chosen without an invalidation story.

The shell is a real artifact, not a concept. After `next build` you can open it at `.next/server/app/<route>.html`. That file — not a response body — is where every claim in this article about "what's in the shell" was checked.

---

## How it works under the hood

### The prerender pass aborts; it does not lie

The interesting design decision is what happens when the prerender pass hits `cookies()`.

It does not return `undefined`. It does not return an empty store. It **aborts the subtree**. The abort propagates upward until it reaches a `<Suspense>` boundary, and that boundary becomes a hole — the prerender emits the fallback into the shell and marks the position for the request pass.

This is why the fix for "reading cookies made my whole route dynamic" is never a config flag. It is *moving the read below a boundary*:

{EXTRACT:demos/next-lab/app/products/[slug]/recently-viewed.tsx}

Nothing about the *amount* of dynamic work changes when you move that read. What changes is how much of the tree the abort can reach.

The same mechanic explains a rule that otherwise looks arbitrary: `params` and `searchParams` are promises, and you await them **inside** the boundary rather than at the top of the page. Awaiting at the top puts the abort above every boundary you have.

### Sync IO cannot abort — and the rule has a second half

`cookies()` can abort because it is awaited; there is a suspension point to hang the abort on.

`new Date()`, `Date.now()`, `Math.random()`, and `crypto.randomUUID()` have none. They return immediately. If the prerender let them through, it would bake a build-time timestamp or a build-time random number into a static artifact and serve it to every visitor for the life of the deployment. Silent, permanent, wrong.

So Next.js fails the build:

{EXTRACT:demos/next-lab/observations/sync-io-error.txt}

The fix is `connection()` — the explicit form of what `cookies()` does implicitly:

{EXTRACT:demos/next-lab/app/products/[slug]/price-as-of.tsx}

**But sync IO is not banned everywhere.** Inside a `'use cache'` scope it is legal, and it freezes:

{EXTRACT:demos/next-lab/observations/date-in-cache-scope.txt}

Those two results are one rule: **sync IO is refused where nothing bounds its staleness, and permitted where `cacheLife` does.** A timestamp inside a cached scope is part of an entry that expires — as stale as the data beside it, no staler. Outside one, it's frozen for the deployment. *(That unification is an inference from two measured behaviours, not documented rationale.)*

The trap it creates is worth stating plainly, because nothing in the output reveals it: **a cached timestamp describes when the entry was created, never when it was read.** The looser the lifetime, the worse the lie.

### `'use cache'` moves work back into the shell

If `<Suspense>` says "this can't be in the shell," `'use cache'` says "this can, despite doing I/O."

{EXTRACT:demos/next-lab/lib/catalog.ts#getProduct}

The cache key is derived by the compiler rather than written by you, from the build ID and the **serialized arguments**.

Two consequences pull in opposite directions.

**The good one:** a class of stale-key bugs disappears. You cannot forget to add an argument to a key array, because there is no key array.

**The dangerous one:** anything read from ambient state at execution time cannot be in the key — and the framework can only stop you when that ambient state is an API it recognises. Reading `cookies()` inside a cached scope is rejected. This is not:

{EXTRACT:demos/next-lab/lib/billing-leak-b.ts}

A cached function has no idea who is asking. Alice's data is stored; Bob's request matches the same key. The full treatment, including a third form that leaks *with* an argument, is in [`user-a-sees-user-b-data`](../../recipes/caching/user-a-sees-user-b-data.md).

One more operational consequence: the build ID is in every key, and the default store is in-memory. **Cache entries do not survive a deploy or an instance teardown.** The old `fetch` Data Cache and `unstable_cache` did. Teams migrating meet this as a post-release cost spike rather than a bug report.

### Lifetime decides placement, not just freshness

A cache profile has three clocks — `stale`, `revalidate`, `expire` — and a short enough one removes content from the prerender entirely.

Measured, with only the alerts' `cacheLife` changed between builds:

{EXTRACT:demos/next-lab/observations/alerts-minutes-build.txt}

{EXTRACT:demos/next-lab/observations/alerts-seconds-build.txt}

So `cacheLife('seconds')` does not mean "cached, briefly." It means **"streamed, with a server-side cache in front of it."** The answer you picked was "cache it"; the answer the framework acted on was "stream it." Not a gotcha — the framework refusing to prerender something that would be stale before anyone saw it — but it explains build output that otherwise looks wrong.

### Validation, and why a passing dev server proves nothing

Because the framework can no longer guess, it tells you when you haven't decided. But the reporting is asymmetric:

{EXTRACT:demos/next-lab/observations/insight-vs-build-error.txt}

The same diagnostic renders a `200` with a silent body in `next dev` and **fails the build**. Dev under-reports severity. If you are testing through a script, or driving an agent, a passing page is not evidence of correctness *or* of buildability.

`export const instant = false` is the explicit "not yet" — it permits a segment to block and silences the diagnostic. Two things worth knowing before reaching for it:

- It **does not** clear sync-IO errors. It is a latency statement; those are correctness failures.
- It is **not free**. A route carrying it is reported as `ƒ` Dynamic rather than `◐` — the segment loses its shell, which is the thing you were trying to keep.

### What the client does with the shell

The shell is also the unit of prefetching. When a `<Link>` prefetches, it pulls the target route's shell; on click the router renders it immediately and streams the holes in behind. "Make the shell as large as honestly possible" is therefore a performance strategy rather than an aesthetic preference.

One caution about measuring that: **time-to-first-byte cannot distinguish a good shell from a bad one.** A route with three structured skeletons and a route with one generic placeholder flush at the same speed and finish at the same time; what differs is when each piece of content arrives. See [`static-shell-and-streaming`](../rendering/static-shell-and-streaming.md) for the measurement that does show it.

One behaviour worth knowing before you meet it as a bug: navigating away no longer unmounts the previous route. React's `<Activity>` keeps it in `hidden` mode. Effects clean up and re-run, but `useState`, form inputs, and scroll survive a round trip. Code relying on unmounting to reset state now needs to reset explicitly.

---

## Basic usage

Two files. This is the entire opt-in.

{EXTRACT:demos/next-lab/next.config.ts}

{EXTRACT:demos/next-lab/app/basic/page.tsx}

Run `next build`, then read `.next/server/app/basic.html`. The cached section is there; the cookie-reading section is a fallback.

Do **not** evaluate caching behaviour in `next dev`. Dev disables prefetching and behaves differently around cache entries. Every caching claim in this repository is verified with `next build && next start`.

---

## Walkthrough — one product page, all four answers

A single route using every answer, because that is the fastest way to make the model concrete:

- a **catalog record** that is the same for everyone → *cache it*
- a **live inventory count** that must be current → *stream it*
- a **recently-viewed strip** read from a cookie → *stream it*
- a **"prices as of" timestamp** → *stream it, after `connection()`*
- an **add-to-cart control** with local UI state → *push it to the client*

### Step 1 — the cached data access

{EXTRACT:demos/next-lab/lib/catalog.ts#getProduct}

Three things are load-bearing, and none is the directive. `slug` is an **argument**, so it's in the key — one entry per product. `cacheTag` gives the write side a handle. `cacheLife('hours')` is a ceiling, not a promise; tag invalidation still wins.

### Step 2 — the page as a layout of boundaries

{EXTRACT:demos/next-lab/app/products/[slug]/page.tsx}

Note what the page component is: it is not `async` and awaits nothing. Its entire job is to declare where the shell ends.

`params` is passed down as a promise rather than awaited here. Awaiting it in `Page` would put the abort above every boundary, leaving no shell for any slug `generateStaticParams` didn't prerender.

### Step 3 — the streamed holes

{EXTRACT:demos/next-lab/lib/inventory.ts#getLiveStock}

No `'use cache'`. That's the decision, not an omission — inventory that is thirty seconds stale sells things you don't have.

{EXTRACT:demos/next-lab/app/products/[slug]/recently-viewed.tsx}

The cookie is read **here**, in the uncached component, and the ids go to the cached lookup as an argument. The lookup can be cached; the *knowledge of who is asking* cannot.

{EXTRACT:demos/next-lab/app/products/[slug]/price-as-of.tsx}

Without `await connection()`, this file fails the build.

### Step 4 — the client leaf

{EXTRACT:demos/next-lab/app/products/[slug]/add-to-cart.tsx}

`'use client'` sits on the **leaf**, not the page. The header around it stays a Server Component and stays in the shell.

### Step 5 — verify the loop

```bash
pnpm build
pnpm start
```

1. Read `.next/server/app/products/aeron-chair.html` — name, price, and description present; the inventory skeleton present; the timestamp absent. **Read the file, not the response** — a streamed response contains the fallback *and* the resolved content, so `curl`, view-source, and DevTools all show a completed stream.
2. Request a slug `generateStaticParams` didn't return. Shell first, then content.
3. Delete `await connection()` from `price-as-of.tsx` and rebuild. The build should fail with the error shown above.
4. Add `export const instant = false` to that broken version and rebuild. **It still fails.** That second failure is the latency-versus-correctness distinction, demonstrated.
5. Load the page with two different `recently-viewed` cookies and confirm the strips differ.

Steps 3 and 4 are the ones people skip, and they are the ones that make the mechanism stick.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 1, 2, 7, 8, 9, 19.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Default caching posture | Cached unless you opted out | Dynamic unless you opt in | Caching moved from a **route classification resolved during build planning** to **per-scope entries with compiler-derived keys**. There is no longer one answer per route to classify. |
| What "dynamic" describes | The whole route | A boundary inside the route | One render pass became **two** — prerender and request — with `<Suspense>` marking the seam. "Dynamic" is a property of the subtree below a boundary. |
| Cost of reading `cookies()` | De-opted the entire route | De-opts only up to the nearest boundary | Runtime APIs went from **setting a flag the planner reads** to **aborting the prerender at their call site**. Abort propagation determines blast radius. |
| Opting a route out of caching | `export const dynamic = 'force-dynamic'` | Nothing to write; delete it | The opt-out disappeared because the thing it opted out of no longer exists. Keeping the export is now a build error. |
| Cache lifetime | `export const revalidate = 3600` on the segment | `cacheLife('hours')` inside a cached scope | A **whole-route declaration** became a **profile on one entry**. One route can hold many entries with different lifetimes — and lifetime now also determines whether content can be prerendered at all. |
| Cache keys | Written by hand: `unstable_cache(fn, ['user', id], …)` | Derived by the compiler from the arguments | Key correctness moved from **your discipline** to **the compiler's analysis** — removing a class of stale-key bugs and creating a new one, since anything read at execution time is not in the key. |
| Persistence | Data Cache and `unstable_cache` survived deploys | Build-ID-keyed and in-memory; durability is opt-in | Storage moved from a framework-managed persistent layer to an in-process default with a pluggable handler. Every deploy starts cold unless you pay for it not to. |
| Navigating away | The route unmounted; state discarded | `<Activity>` keeps it in `hidden` mode | The router stopped destroying the previous tree, so persistence became the default and resetting the explicit act. |

---

## Real-world patterns

**Design the shell first.** Before writing a component, ask what a user should see 50ms after clicking with zero data. That answer *is* your shell; boundaries go where that picture ends.

**Boundaries belong at the smallest honest unit.** One around the whole page and one around the single personalized widget produce the same correctness and very different experiences.

**Watch the shared layout.** A single `cookies()` read in a root-layout header de-opts every route beneath it. Highest-leverage mistake in the model, because the blast radius is the whole app. When the value must drive an `<html>` attribute, an inline script that sets it before paint keeps the shell intact.

**Fallbacks are shells, not spinners.** They are prerendered HTML shipped to everyone. A fallback that doesn't match its content guarantees a layout shift on every request.

**Cache the lookup, not the identity.** Read identity outside the cached scope and pass the id in. Keeping that split habitual is what prevents the leak class.

**Verify against the build artifact.** `.next/server/app/<route>.html` is the only place the shell exists in isolation.

**Budget for cold caches at deploy.** Build-ID-keyed and in-memory means the first minutes after a release are uncached.

---

## API and type reference

| Surface | Import | Role in the model |
| --- | --- | --- |
| `cacheComponents: true` | `next.config.ts` | Enables the model. Requires the Node.js runtime. |
| `partialPrefetching: true` | `next.config.ts` | Extracts reusable shells across routes for prefetching. |
| `'use cache'` | directive | Marks a file, component, or async function as reusable. Must be `async`. |
| `'use cache: remote'` | directive | Same, with durable storage. Network round trip. |
| `'use cache: private'` | directive | **Experimental.** Browser-memory only; `connection()` prohibited. |
| `cacheLife(profile)` | `next/cache` | Lifetime for the enclosing scope. Also determines prerender eligibility. |
| `cacheTag(tag)` | `next/cache` | Invalidation handle for the enclosing scope. |
| `connection()` | `next/server` | "Do not prerender past this line." Prohibited inside cached scopes. |
| `<Suspense>` | `react` | Defines the shell/hole seam. |
| `export const instant = false` | segment config | Permits blocking and silences the diagnostic. Costs the segment its shell. Does not clear sync-IO errors. |
| `after(fn)` | `next/server` | Work that runs after the response is sent. |

---

## Common mistakes

**1. `'use cache'` at the top of the page to "make it fast."** One coarse entry keyed by almost nothing, and every runtime read below it becomes illegal. Cache the data access, not the route.

**2. Awaiting `params` or `searchParams` at the top of a page.** The abort lands above every boundary and there is no shell for un-prerendered paths.

**3. Reading `cookies()` or `headers()` in a shared layout.** One line, whole-app blast radius.

**4. Reaching for `instant = false` at a sync-IO error.** It won't clear it, and it costs the segment its shell besides.

**5. Evaluating caching in `next dev`.** Different prefetch behaviour, different cache behaviour, different conclusions.

**6. Assuming cache entries survive a deploy.** Build-ID-keyed and in-memory.

**7. Reading ambient state inside a cached scope.** `cookies()` there is rejected; a module-level variable is not, and leaks. The argument must identify the data.

**8. `useSearchParams` in a Client Component without a boundary.** It always suspends during prerendering, wherever it sits.

**9. Copying `export const dynamic = 'force-dynamic'` from a tutorial.** A build error now, which is a mercy. The silent version is a pre-16 fetch idiom that still compiles and means the opposite.

**10. Trusting a 200 in dev.** The same diagnostic that renders fine there can fail the build.

**11. Verifying the shell in a browser.** View-source shows a completed stream. Read the build artifact.

---

## Exercises

**1. Find the shell.** Take a route you already have and, without changing code, write down which parts a user could see with no request. Then count the `<Suspense>` boundaries. Disagreement is your first misplaced boundary.

**2. Break it on purpose.** Move `await params` from `ProductHeader` up into `Page`. Build, read the error, then move it back.

*Hint: compare the build output for `/products/[slug]` before and after — the prerender status is the tell.*

**3. Classify a real page.** Take a page with five distinct pieces of data and assign each an answer. For every "stream it," name what the user looks at while it loads. For every "cache it," name the tag that invalidates it and the write that fires it.

*Hint: if you can't name the invalidating write, the answer is "stream it."*

---

## Summary

- A route is a **static shell with holes**, produced by two passes: prerender and request.
- `<Suspense>` marks the seam. `'use cache'` moves work back across it into the shell.
- Runtime APIs **abort** the prerender at their call site; the abort propagates to the nearest boundary. That propagation, not a config flag, determines blast radius.
- Sync IO cannot abort, so it hard-errors — **except inside a cached scope**, where it is legal and freezes at entry creation.
- Cache keys are derived from **arguments**. Anything read from ambient state at execution time is not in the key, and only the recognised APIs are guarded.
- Lifetime determines placement: too short, and content leaves the prerender entirely.
- Dev **under-reports severity** — the same diagnostic can be advisory there and fatal at build.
- Every piece of data gets one of four answers: cache, stream, block, or push to the client.

---

## See also

- [`foundations/server-and-client-components`](./server-and-client-components.md) — where the client boundary goes and what may cross it
- [`rendering/static-shell-and-streaming`](../rendering/static-shell-and-streaming.md) — the shell/hole mechanics in depth
- [`caching/cache-components-model`](../caching/cache-components-model.md) — why the default inverted
- [`foundations/rules-of-the-server-boundary`](./rules-of-the-server-boundary.md) — the enforcement matrix
- [`rendering/client-side-rendering`](../rendering/client-side-rendering.md) — the fourth answer
- [`caching/user-a-sees-user-b-data`](../../recipes/caching/user-a-sees-user-b-data.md) — the leak class in full

---

## References

- Next.js — `next.config.js: cacheComponents`, `partialPrefetching`
- Next.js — Getting Started: Caching, Partial Prerendering
- Next.js — Directives: `use cache`, `use cache: remote`, `use cache: private`
- Next.js — Functions: `connection`, `cacheLife`, `cacheTag`, `after`
- Next.js — Guides: Migrating to Cache Components, Instant Navigation
- Next.js blog — Next.js 16.3 (2026-08-03)
- React — `<Suspense>`, `<Activity>`

---

## Demo source

`demos/next-lab/app/products/[slug]/`, `demos/next-lab/app/basic/`, `demos/next-lab/lib/catalog.ts`, `demos/next-lab/lib/inventory.ts`, `demos/next-lab/lib/billing-leak-b.ts`, and the capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0`. This **supersedes the session-2 draft**, which was written before anything in it had been measured. Six claims changed: shell verification moved from view-source to the build artifact; the key description dropped "closures" as misleading; the leak example was replaced because the form it showed is rejected rather than silent; `instant = false` was found to cost the segment its shell; sync IO was found legal and frozen inside cached scopes; and the insight/error severity split was found to be a dev/build asymmetry rather than two severities. Every code block and observation is extracted; none is hand-typed.
