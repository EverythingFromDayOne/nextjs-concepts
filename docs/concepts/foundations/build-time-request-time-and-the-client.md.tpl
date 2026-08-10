---
article_id: build-time-request-time-and-the-client
concept_folder: foundations
wave: 1
related:
  - foundations/thinking-in-the-app-router
  - rendering/static-shell-and-streaming
  - caching/cache-components-model
  - foundations/server-and-client-components
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-10
status: review
---

# Build time, request time, and the client

> **Lead with this.** Your code can run at three different moments, and most Next.js bugs are code that assumed a moment it doesn't have. The framework used to let you guess; it now makes you say which one you meant — and the way it makes you say it differs depending on whether the value you want can *wait*.
>
> That last distinction is the whole article. `cookies()` can wait, so it suspends and you fix it with a boundary. `new Date()` cannot wait, so it errors and no boundary or config flag will save you.

---

## What it is

Three moments, and a fourth that is easy to miss:

| Moment | When | What exists |
| --- | --- | --- |
| **Build time** | `next build`, and background regeneration afterwards | Your code, your cached data. **No request.** |
| **Request time** | Per request, filling the holes | The request: cookies, headers, URL, connection |
| **Client** | After hydration, and on every interaction | The DOM, the viewport, device APIs, user input |
| **After** | Once the response has been sent | The request context, but nobody waiting on you |

The boundary between these is **not the file**. The same component runs at build time when it can and at request time when it must. What decides is whether the work it does can be reused.

---

## How it works under the hood

### The prerender has no request — not a degraded one, none

This is the fact everything else follows from. During the prerender pass there is no cookie jar, no header map, no URL, no client IP. Not empty ones. Absent ones.

So an API that reads the request has two options, and Next.js picks per API based on one property: **can this call wait?**

### Class one: suspendable

`cookies()`, `headers()`, `searchParams`, `params`, `connection()`. These are awaited, so there is a suspension point to hang an abort on. During the prerender they abort their subtree, the abort rises to the nearest `<Suspense>`, and that boundary becomes a hole.

The fix is always structural: put a boundary above the call. Nothing about the code changes — only how much of the tree the abort can reach.

`connection()` is the explicit member of this family. It is what `cookies()` does implicitly, with the implicit part removed:

{EXTRACT:demos/next-lab/app/products/[slug]/price-as-of.tsx}

Read it as a declaration: *do not prerender past this line.* Which also explains why it is prohibited inside `'use cache'` — a cache entry that depends on the connection is a cache entry with no reuse.

### Class two: not suspendable — one rule, two scopes

`new Date()`, `Date.now()`, `Math.random()`, `crypto.randomUUID()`. These return immediately. There is no await, so there is nothing to abort on.

{EXTRACT:demos/next-lab/antipatterns/sync-io-variants.tsx}

Outside a cached scope, the prerender refuses them. All four primitives error; none silently bake into the shell:

{EXTRACT:demos/next-lab/observations/sync-io-variants.txt}

(The shorter capture from the product page, kept for the walkthrough restore step:)

{EXTRACT:demos/next-lab/observations/sync-io-error.txt}

Inside `'use cache'`, the same `new Date()` builds and runs — and freezes at entry creation:

{EXTRACT:demos/next-lab/lib/stamped.ts#getStamped}

{EXTRACT:demos/next-lab/observations/date-in-cache-scope.txt}

Those are not two facts. They are one rule, stated observationally:

> **Sync IO is refused where nothing bounds its staleness, and permitted where `cacheLife` does.**

*Inference (not a documented rationale):* outside a cached scope, a build-time timestamp is stale relative to nothing — frozen for the life of the deployment. Inside one, it is part of a cache entry that expires, so it is exactly as stale as the data it accompanies. That is a structural difference, not a special case for dates.

### Cached timestamps are a trap that scales with lifetime

The error's own fix list offers `"use cache"`. That is not a way to get "now." It is a way to freeze a clock into the cache entry — legal, and wrong for every reader who treats it as request time.

The looser the lifetime, the worse the trap. `cacheLife('minutes')` yields a timestamp that is minutes old and reads as *now*. `cacheLife('max')` yields one that may be weeks old and reads exactly the same. A cached timestamp describes **when the entry was created**, never when it was read — and nothing in the rendered output says which. The two identical ISO strings above, 2.5 seconds apart, are the evidence.

Prefer no timestamp in a cached section (see `BuildTimeSection`) over a stamped one that readers will misread as "now."

### Why `instant = false` fixes one and not the other

The two classes fail for different reasons, and the escape hatch only addresses one of them.

- `instant = false` means **"this segment may block."** It is a statement about latency, and it silences the validator's insight about a non-instant navigation.
- A sync-IO error means **"this value cannot be computed before the request exists."** It is a statement about correctness.

A latency opt-out cannot resolve a correctness failure:

{EXTRACT:demos/next-lab/antipatterns/instant-false-doesnt-help.tsx}

{EXTRACT:demos/next-lab/observations/instant-false-syncio.txt}

Reaching for the flag when you see a sync-IO error is the clearest sign the distinction hasn't landed yet. The fix is `connection()` behind a boundary, or moving the value to the client where a real clock exists.

### Dev under-reports severity

Docs talk about **errors** and **insights**, but that is a presentation taxonomy — not a reliable map onto "stops the build" vs "doesn't." The same diagnostic id can be advisory in `next dev` and fatal in `next build`.

Bare `await connection()` at a page root, no `<Suspense>`, no `instant = false`:

{EXTRACT:demos/next-lab/observations/insight-vs-build-error.txt}

In both halves the log line starts with `Error:` — not "Insight", not "Warning." Docs still call the non-fatal-in-dev presentation an insight. The weaker half of the claim still stands: **the diagnostic is absent from the HTTP response.** Dev returns `200` with rendered HTML; you will not find the message in the body. It lives in the overlay, the server log, or MCP.

The stronger half is the one that costs deploys: **a passing `next dev` is not evidence of buildability.** `/after-demo` needed a `<Suspense>` around `connection()` for the same reason — without it, `next build` exits 1 on `blocking-prerender-dynamic`.

### `after()` — the moment after the moment

Work that must happen but that the visitor should never wait for — analytics, audit logs, cache warming — goes in `after()`. It runs once the response has been sent, still inside the request context:

{EXTRACT:demos/next-lab/app/after-demo/page.tsx}

{EXTRACT:demos/next-lab/observations/after-ordering.txt}

The audit write takes 300ms and does not appear in the visitor's total. The ordering in that capture is the proof.

### The client is a fourth environment, not a later phase

`useEffect` never runs on the server. A Client Component's first render happens on the server, is sent as HTML, and the browser must agree with it during hydration — which is why anything device-specific has to start as a null render and arrive afterwards:

{EXTRACT:demos/next-lab/app/when/client-section.tsx}

The `typeof window === 'undefined'` line is the honest version of a check people usually write to suppress a hydration warning. It doesn't suppress anything here; it shows both answers, because both are real.

---

## Basic usage

The three moments in one route:

{EXTRACT:demos/next-lab/app/when/page.tsx}

---

## Walkthrough — make each moment prove itself

### Step 1 — build time, and what it cannot say

{EXTRACT:demos/next-lab/app/when/sections.tsx#BuildTimeSection}

Note the absence. This section shows no timestamp, and not for lack of trying: a value describing when it ran would be computed once and served forever. **Build-time code cannot honestly report its own moment.** That constraint is the entire sync-IO rule in one sentence.

### Step 2 — request time, unlocked explicitly

{EXTRACT:demos/next-lab/app/when/sections.tsx#RequestTimeSection}

`await connection()` first, `new Date()` second. Reverse them and the build fails. The order is the semantics.

### Step 3 — the client, and its null first render

{EXTRACT:demos/next-lab/app/when/client-section.tsx}

The server sends "Not hydrated yet." The browser renders the same thing, hydrates, then the effect fills it in. Skipping the null state — reading `window` during render — is a hydration error rather than a clever shortcut.

### Step 4 — after the response

{EXTRACT:demos/next-lab/lib/audit.ts}

Then read the ordering capture from Step 4 of the observation pass. Response complete, *then* audit written.

### Step 5 — verify the loop

```bash
pnpm build && pnpm start
```

1. `.next/server/app/when.html` — the build-time section is present; the request-time section is a fallback; the client section shows its null state.
2. Load the page twice. The request timestamp changes; the build-time figures don't.
3. Delete `await connection()` from `RequestTimeSection` and rebuild. Read the error. Restore.
4. Add `export const instant = false` to that same broken version and rebuild again. It still fails. **That second failure is the one worth seeing** — it is the difference between latency and correctness, demonstrated rather than asserted.
5. Watch the server log while requesting `/after-demo`. The audit line arrives after the response.

Step 4 is the one people skip, and it is the only one that teaches the distinction.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 1, 7, 8, 21.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Declaring when code runs | Per page, by which data function you exported — `getStaticProps` vs `getServerSideProps` | Per call site, by whether the work is cached and where the boundaries are | The declaration moved from **a page-level export the build planner reads** to **an inference from what each call does**. One page can now span all three moments; the old model made you pick one for the whole page. |
| `new Date()` in a component | Ran fine — baked at build for a static page, fresh per request for a dynamic one | Hard build error outside `'use cache'` unless preceded by `connection()`; legal and frozen inside a cached scope | The old model let the page's classification decide silently. With classification gone per-route, an unsuspendable read has no context to make it safe unless a `cacheLife` bounds the entry — so the framework refuses the unbounded case rather than guessing. |
| Opting into request time | `getServerSideProps`, or `noStore()`, or reading `cookies()` and accepting the route-wide de-opt | `connection()` at the exact line, or a runtime API below a boundary | Opting in went from **a route-wide switch** to **a statement at the call site**, so the cost is scoped to the subtree instead of the page. |
| Deferred work | No first-class mechanism; you fired a promise and hoped the runtime didn't freeze | `after()`, stable | Post-response work became part of the request lifecycle rather than a race against the platform's teardown. |
| Finding out you got it wrong | Deploy, observe, guess | Dev overlay / log / MCP naming the component — and `next build` that may treat the same diagnostic as fatal | Detection moved from **production observation** to **development validation**, with the caveat that **dev under-reports severity**: a 200 in `next dev` proves neither correctness nor buildability. |

---

## Real-world patterns

**Ask "which moment?" before "which API?"** Most of the API questions answer themselves once the moment is settled. A value that differs per visitor cannot be build-time, no matter which function you reach for.

**`connection()` documents intent; a bare `cookies()` hides it.** If the reason a subtree is dynamic is a timestamp rather than a cookie, say so with `connection()`. The next reader should not have to infer why a boundary exists.

**Random and unique belong to the client or to the request.** IDs for form fields come from `useId`. Ids for records come from the database or from a request-time call. A `crypto.randomUUID()` at module scope in a Server Component is a single id shared by everyone.

**`after()` is not a background job runner.** It runs in the request's context, after the response. It is right for logging and analytics; it is wrong for anything that must survive a crashed instance or retry on failure. Reach for a queue there.

**Never conclude anything about timing — or buildability — from `next dev` alone.** Dev disables prefetching, behaves differently around cache entries, and under-reports severity for the same diagnostic id. Every claim in this article was measured with `next build && next start` (or an explicit `next build` failure capture).

---

## API and type reference

| Surface | Import | Moment it concerns |
| --- | --- | --- |
| `connection()` | `next/server` | Blocks the prerender; everything after is request time. Prohibited inside cached scopes. |
| `cookies()` / `headers()` | `next/headers` | Request time. Suspends during the prerender. |
| `params` / `searchParams` | page props | Request time. Promises; await inside a boundary. |
| `after(fn)` | `next/server` | After the response is sent, still in the request context. |
| `'use cache'` | directive | Build time — resolves during the prerender. |
| `export const instant = false` | segment config | Latency only. Permits blocking and silences the insight. Does not license a build-time value. |
| `useEffect` | `react` | Client only. Never runs during any server render. |
| `useId` | `react` | The correct source of stable ids across the server/client boundary. |

---

## Common mistakes

**1. Reaching for `instant = false` at a sync-IO error.** It permits blocking; the error is about correctness. Walkthrough step 4 exists to make this stick.

**2. Reading a cached timestamp as "now."** Legal inside `'use cache'`, frozen at entry creation, worse the longer the lifetime. Nothing in the HTML says which.

**3. `crypto.randomUUID()` at module scope.** Evaluated once per process. Every visitor gets the same "unique" id.

**4. Reading `window` during render in a Client Component.** `'use client'` does not mean client-only; that component renders on the server first. Start with a null state and fill it in an effect.

**5. Treating a `200` in `next dev` as a pass.** The diagnostic is absent from the response body *and* may be fatal at `next build`. Dev under-reports severity.

**6. Using `after()` for work that must not be lost.** It is post-response, not durable. A crashed instance takes it with it.

**7. Assuming a cached component runs once, ever.** It runs whenever its entry is missing — after a deploy, after eviction, after expiry. "Build time" means "not per request," not "once."

**8. Debugging timing in `next dev`.** Different prefetch behavior, different cache behavior, different conclusions.

---

## Exercises

**1. Classify five reads.** In an app you have, list five pieces of data and assign each a moment. For every "request time," name what makes it request-specific. If you can't, it is probably build time and you are paying for nothing.

*Hint: "it might change" is not the same as "it differs per visitor."*

**2. Break it twice.** In `/when`, remove `await connection()` and build. Then add `export const instant = false` and build again. Write down, in one sentence each, why the first failed and why the flag didn't fix it.

*Hint: one sentence should contain the word "latency" and the other should contain "correctness."*

**3. Time the `after()`.** Add a deliberate 2-second delay inside `recordView` and re-run the ordering capture. Does the visitor's total move?

*Hint: if it does, the call is not where you think it is.*

---

## Summary

- Code runs at build time, request time, or on the client — plus `after()`, once the response is sent.
- The prerender has **no request**, so request-reading APIs must either suspend or fail.
- **Suspendable** reads (`cookies`, `headers`, `params`, `connection`) abort to the nearest boundary. Fix with structure.
- **Non-suspendable** reads (`new Date`, `Math.random`, `crypto.randomUUID`) hard-error outside a cached scope. Inside `'use cache'` they are legal and freeze with the entry — one rule, two scopes.
- A cached timestamp describes entry creation, never "now"; looser `cacheLife` makes a worse trap.
- `instant = false` is a latency statement. It never licenses a build-time value.
- Dev under-reports severity: the same diagnostic can be a 200 in `next dev` and fatal in `next build`. Absence from the HTTP body is the weaker half of that claim.
- `after()` is post-response, not durable.
- Client Components render on the server first. Device-specific values start null and arrive after hydration.

---

## See also

- [`foundations/thinking-in-the-app-router`](./thinking-in-the-app-router.md) — the four answers, of which this article is the "block on it" and "push to the client" halves
- [`rendering/static-shell-and-streaming`](../rendering/static-shell-and-streaming.md) — where suspendable aborts land
- [`caching/cache-components-model`](../caching/cache-components-model.md) — why uncached I/O is request time by default
- [`foundations/server-and-client-components`](./server-and-client-components.md) — the client boundary as a module graph
- [`deployment/observability-and-instrumentation`](../deployment/observability-and-instrumentation.md) — `after()` at production scale

---

## References

- Next.js — Functions: `connection`, `after`, `cookies`, `headers`
- Next.js — Guides: Migrating to Cache Components
- Next.js — Guides: Instant Navigation
- Next.js — `next.config.js: cacheComponents`
- React — `useEffect`, `useId`, hydration

---

## Demo source

`demos/next-lab/app/when/`, `demos/next-lab/app/after-demo/`, `demos/next-lab/lib/when.ts`, `demos/next-lab/lib/stamped.ts`, `demos/next-lab/lib/audit.ts`, the two files in `demos/next-lab/antipatterns/`, and the capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0`. Session 6 experiments measured: (1) all four sync-IO primitives caught outside cache (`sync-io-variants.txt`); (2) `instant = false` does not clear sync-IO (`instant-false-syncio.txt`); (3) `new Date()` inside `'use cache'` builds, runs, and freezes — presented as one rule with Exp1 (`date-in-cache-scope.txt`); (4) `after()` post-response (`after-ordering.txt`). **Falsified and rewritten:** the claim that insights are a non-fatal severity ladder — `blocking-prerender-dynamic` is `Error:` + HTTP 200 in `next dev` and **fatal in `next build`** without `instant = false` or a boundary (`insight-vs-build-error.txt`). Reused session-3 product-page sync-IO text. Every code block and observation here is extracted; none is hand-typed.
