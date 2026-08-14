---
article_id: cache-components-model
concept_folder: caching
wave: 1
related:
  - foundations/thinking-in-the-app-router
  - caching/use-cache-directive
  - caching/cache-lifetimes
  - caching/the-other-cache-layers
  - migration/adopting-cache-components
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-10
status: review
---

# The Cache Components model

> **Lead with this.** Next.js used to cache aggressively and let you opt out. It now caches nothing and makes you opt in. That inversion is the reason most Next.js advice you will find — in tutorials, in answers, in model completions — is not merely dated but **actively wrong**: the same code now means the opposite thing, and the mismatch is invisible in `next dev`.
>
> The model that replaced it is small. Every piece of data answers one of four questions — **cache it, stream it, block on it, or push it to the client** — and Next.js validates in development that you answered.

This is the thesis article of this repository. Every "Then vs now" section elsewhere cites it.

---

## What it is

`cacheComponents: true` is one decision that changes one default:

{EXTRACT:demos/next-lab/next.config.ts}

After that line, **nothing is cached unless a `'use cache'` directive says so.** Data access is dynamic by default. Next.js prerenders whatever static shell it can, serves it immediately, and streams the rest.

### Why the default was inverted

The old model was not one cache. It was four, layered, each with a different opt-out:

<!-- legacy-ok:start reason=historical description of the pre-16 four-layer cache model -->
| Layer | What it cached | How you opted out |
| --- | --- | --- |
| Request memoization | Duplicate `fetch`es in one render pass | Nothing — automatic, per-request |
| Data Cache | `fetch` responses across requests and deploys | `cache: 'no-store'`, `next: { revalidate: 0 }` |
| Full Route Cache | Rendered HTML + RSC payload per route | `export const dynamic = 'force-dynamic'`, or *accidentally*, by reading `cookies()` |
| Router Cache | Payloads on the client, per navigation | `staleTimes` config, `router.refresh()` |
<!-- legacy-ok:end -->

Nothing in that table is unreasonable in isolation. Together they produced a specific, well-documented failure mode: **you could not look at a component and know whether it was cached.** The answer depended on layers you hadn't written, in files you weren't reading, keyed by rules you hadn't opted into. "Why is my page serving stale data" and "why is my page not caching at all" were the same question with different luck, and answering it meant reading framework documentation rather than reading your own code.

The fix was not a better set of defaults. It was removing the implicitness: one primitive, applied where you can see it, with the caching decision visible at the call site.

### The four answers

Every piece of data in a route gets exactly one:

| Answer | Mechanism | Choose it when |
| --- | --- | --- |
| **Cache it** | `'use cache'` + `cacheLife` + `cacheTag` | The value is the same across many requests, and you can name the write that invalidates it. |
| **Stream it** | `<Suspense>` | The value differs per request, and the user has something else to look at meanwhile. |
| **Block on it** | `export const instant = false` | A shell would be a lie — the page *is* the data. |
| **Push it to the client** | `'use client'` + fetch after hydration | The value is device-local, or changes on interaction. |

The useful discipline is the tie-breaker: **if you cannot name the write that invalidates it, the answer is "stream it," not "cache it."** Most stale-data bugs are a "cache it" chosen without an invalidation story.

---

## How it works under the hood

### What the flag actually turns on

`cacheComponents: true` is not a caching toggle. It switches on the rendering architecture described in [`thinking-in-the-app-router`](../foundations/thinking-in-the-app-router.md):

<!-- legacy-ok:start reason=names the removed PPR flags as removed -->
- **The prerender/request split.** Partial Prerendering stopped being an experiment and became the way routes render. `experimental.ppr` and the `experimental_ppr` segment config were removed, because there is nothing left to opt into.
<!-- legacy-ok:end -->
- **Abort-based dynamism.** Runtime APIs abort the prerender at their call site instead of setting a route-level flag.
- **The cache directives.** `'use cache'`, `'use cache: remote'`, and the experimental `'use cache: private'` become available, along with `cacheLife` and `cacheTag`.
- **Validation.** Development checks whether each route can render instantly and reports what is blocking it.
- **A runtime constraint.** Cache Components requires the Node.js runtime; `runtime = 'edge'` is deprecated and incompatible.

It also retires a family of exports. `dynamic`, `revalidate`, and `fetchCache` on a route segment now **error** rather than being ignored — which is the right call, because a silently-ignored caching directive is exactly the class of bug the model exists to remove.

### The decision is not binary — lifetime moves it

Here is the part that is genuinely non-obvious, and the reason "cache it" and "stream it" are ends of a spectrum rather than two boxes.

A cache profile has three clocks, and they are not the same clock:

- **`stale`** — how long the *client* router serves cached content without checking the server.
- **`revalidate`** — how long before the *server* regenerates in the background, serving the old value meanwhile.
- **`expire`** — how long before the server must regenerate *synchronously*, making the next request wait.

The default profile is `stale` 5 minutes, `revalidate` 15 minutes, `expire` never.

Now the mechanism: **a short enough lifetime disqualifies content from the prerender entirely.**

| Condition | Effect |
| --- | --- |
| `revalidate: 0`, or `expire` under 5 minutes | Excluded from prerenders — becomes a dynamic hole resolved at request time |
| `stale` under 30 seconds | Excluded from prerenders, because a prefetch would expire before the user could click |
| `stale` between 30 seconds and 5 minutes | Prerendered, but excluded from the route's App Shell |

Of the preset profiles, only `seconds` crosses any threshold — its one-minute `expire` keeps it out of prerenders.

So `cacheLife('seconds')` does not mean "cached, briefly." It means **"streamed, with a server-side cache in front of it."** The answer you thought you picked was "cache it"; the answer the framework acted on was "stream it." That is not a gotcha — it is the framework refusing to prerender something that would be stale before anyone saw it — but it will surprise you once, and it explains build output that otherwise looks wrong.

A related enforcement, which exists because the surprise would otherwise be silent: when a short-lived cached function is nested inside a `'use cache'` scope that has **no explicit `cacheLife`**, the outer scope's lifetime would silently be dragged down to the inner one's. Next.js throws during prerendering instead. The nested cache can easily be somewhere you aren't looking — an imported module, or a third-party dependency — so the error is often the first you hear of it. The fix is to state the outer lifetime explicitly, which is why "call `cacheLife` in every `'use cache'` scope" is a real convention and not ceremony.

Lifetimes also compose asymmetrically. An explicit outer `cacheLife` always wins, longer or shorter. Without one, an inner cache with a *shorter* lifetime can pull the outer scope down, while an inner cache with a *longer* one cannot push it up past the default.

### Cache keys are derived, not written

The old model made you write keys: `unstable_cache(fn, ['user', id], opts)`. The new one derives them — from the build ID and the serialized arguments. **Anything read from ambient state at execution time cannot be in the key** — and the framework can only stop you when that ambient state is a Next API it recognizes.

Two consequences, and they pull in opposite directions.

**The good one:** a whole class of stale-key bugs disappears. You cannot forget to add an argument to the key array, because there is no key array.

**The dangerous one:** anything that is *not* an argument is not in the key. A cached function has no idea who is asking.

Next.js guards the obvious version of this. Reading `cookies()` inside a cached scope — as in the leak-a demo — throws at request time:

{EXTRACT:demos/next-lab/lib/billing-leak-a.ts#getDashboardLeakA}

{EXTRACT:demos/next-lab/observations/leak-a-runtime-error.txt}

Note **when** it throws: at request time, not at build. Whether a dynamic API is reachable through a call chain isn't statically decidable, so the check has to be dynamic — which means a path only exercised for signed-in users won't fail until a signed-in user hits it. A build that goes green is not evidence that no cached scope reads the request.

The vectors that do leak evade the key rather than the guard.

**Ambient module state.** No Next API is touched, so nothing fires — and the value is read at execution time, so it cannot be in the key:

{EXTRACT:demos/next-lab/lib/billing-leak-b.ts}

Alice's dashboard is stored. Bob's request matches the same key and receives it.

**A key that doesn't discriminate.** Here the argument *is* in the key. It is simply the same argument for every signed-in user:

{EXTRACT:demos/next-lab/lib/billing-leak-c.ts#getDashboardLeakC}

The guard is satisfied. The key is honest. The result is still wrong.

So the rule is not merely "read outside, pass in" — it is **the argument must identify the data**. Passing `scope` is passing an argument, and it leaks anyway. The working form takes the identifying value as the argument:

{EXTRACT:demos/next-lab/lib/billing.ts#getUsage}

The habit that falls out — **read runtime data outside cached scopes, pass values in as arguments that identify the data** — is the single most load-bearing habit in this model. It has its own article and its own recipe because it is the one whose failure is a security incident rather than a stale render.

### Storage is not what it was

`'use cache'` defaults to in-memory storage, and the build ID is part of every key. Both matter operationally:

- **Entries do not survive a deployment.** Every release starts cold.
- **Entries do not survive instance teardown.** In serverless, that is often per-request in practice.

The `fetch` Data Cache and `unstable_cache` both persisted across deploys and instances. Teams migrating from 15 meet this as a cost and latency spike immediately after each release, not as a bug report. Durable storage is available — `'use cache: remote'` or a configured cache handler — at the price of a network round trip on every cache check, and, on most platforms, a bill.

### Validation is part of the model, not a linter

Because the framework can no longer guess, it tells you when you haven't decided. In development, Next.js validates whether navigating into each route renders instantly and surfaces what blocks it. Docs call the presentations **errors** and **insights** — but that is a presentation taxonomy, not a reliable map onto "stops the build" vs "doesn't."

**The diagnostic is absent from the HTTP response** — that is the weaker half. A flagged route still returns `200` with rendered HTML in `next dev`. The message lives in the overlay, the server log, or MCP `get_errors`. Agents and scripts that only curl the page will miss it.

**Dev under-reports severity** — that is the stronger half. The same diagnostic id can be advisory in `next dev` and fatal in `next build`. Bare `connection()` at a page root (no boundary, no `instant = false`) returns HTTP 200 in dev and exits the production build:

{EXTRACT:demos/next-lab/observations/insight-vs-build-error.txt}

Earlier session-3 capture on `app/insight-probe/` (root-level `cookies()` + uncached DB read, no Suspense, no `instant = false`) recorded the same pattern for the HTTP half — log prefix `Error:`, body silent. Overlay and MCP were not separately confirmed:

{EXTRACT:demos/next-lab/observations/insight-blocking-prerender.txt}

`export const instant = false` is the explicit "not yet" — it marks a segment as allowed to block. It is also the acknowledgement that **quiets the validator**: with the flag set, insights for that segment stop firing. That is precisely its purpose and precisely why it should be temporary — `app/insight-probe/` ships with the flag so `next build` stays green; remove it locally to hear the insight again. Without the flag (or a boundary), the same diagnostic that looked advisory in dev fails the build.

Two things it is not:

- It does **not** force the route dynamic. A genuinely prerenderable route still ships a static shell.
- It does **not** clear synchronous-IO build errors. `new Date()`, `Math.random()`, and `crypto.randomUUID()` still fail the prerender, because those are correctness failures and `instant = false` is a latency statement.

---

## Basic usage

The whole model in one route — runnable at `/basic`.

{EXTRACT:demos/next-lab/app/basic/page.tsx}

Read it as three decisions, not as syntax: announcements are the same for everyone and an editor's publish invalidates them; personal stats differ per request; identity is read where the request exists and handed downward as a value.

---

## Walkthrough — adopting the model on one real route

The most useful thing this article can teach is not the syntax. It is the loop you run when validation starts talking to you. We will take a dashboard that worked fine on Next 15 and drive it through.

### Step 0 — the route as it arrives from Next 15

{EXTRACT:demos/next-lab/legacy/dashboard-page.next15.tsx}

Reasonable Next 15 code. Under `cacheComponents: true` it produces, in order: two config errors, one build error, and two insights.

### Step 1 — enable the flag and delete what now errors

{EXTRACT:demos/next-lab/next.config.ts}

`dynamic` and `revalidate` on a segment now error. Delete both. `dynamic = 'force-dynamic'` has no replacement — everything is dynamic by default, so the export was already describing the new baseline. `revalidate = 60` becomes a `cacheLife` on whatever scope actually needed it, which is not the route.

At this point the route builds worse than it did before: everything renders per request, because nothing has opted in yet. **This is expected and it is the honest state.** The previous version was not faster; it was implicitly cached in ways nobody had chosen.

### Step 2 — classify each of the four reads

Before writing code, answer the question for each one. This table is the actual work; the rest is transcription.

| Read | Same for everyone? | Invalidating write? | Answer |
| --- | --- | --- | --- |
| `getPlans()` | Yes | Admin edits pricing | **Cache it**, tag `plans` |
| `db.usage.forUser(uid)` | No — per user | — | **Stream it** (identity read outside) |
| `fetch(status alerts)` | Yes | None we control; third party | **Cache it**, short lifetime |
| `new Date()` | No — per request | — | **Stream it**, after `connection()` |

Note the third row. There is no write we can hook, so a tag is useless and the honest lever is time. And per the thresholds above, a short enough lifetime will take it out of the prerender — which is fine, as long as we know that is what we chose.

### Step 3 — the cached reads

{EXTRACT:demos/next-lab/lib/billing.ts#getPlans}

{EXTRACT:demos/next-lab/lib/billing.ts#getUsage}

`getUsage` takes `uid` as an argument. It never reads the cookie. That is the whole difference between a per-user cache entry and a cross-user leak.

{EXTRACT:demos/next-lab/lib/status.ts#getAlerts}

No tag, deliberately — nothing in our system can invalidate a third party's status feed. Time is the only honest lever. Measured on `next@16.3.0`: with `cacheLife('minutes')` the alert banner is present in `.next/server/app/dashboard.html`; flip to `'seconds'` and it is absent from that file — present only in the streamed response. Lifetime moved the answer from "cache it" to "stream it."

### Step 4 — the page becomes a layout of boundaries

{EXTRACT:demos/next-lab/app/dashboard/page.tsx}

`Plans` and `Alerts` are cached, so they resolve during the prerender and land in the shell — their `<Suspense>` boundaries cost nothing there. `Usage` reads a cookie, so its boundary is the hole. `LastRefreshed` needs a real request, and `connection()` says so.

### Step 5 — verify the loop

```bash
pnpm build && pnpm start
```

1. After `pnpm build`, open `.next/server/app/dashboard.html`. The plan table and alert banner should be in that prerender artifact. The usage skeleton may be there as the hole's fallback; the timestamp from `LastRefreshed` should not. Recorded with `cacheLife('minutes')` on alerts:

{EXTRACT:demos/next-lab/observations/alerts-minutes-build.txt}

2. Change `getAlerts` to `cacheLife('seconds')` and rebuild. Compare `.next/server/app/dashboard.html` again: the alert banner is absent from the prerender (it still arrives in the stream — `curl` will show it either way). **Change it back.** That round trip is the lifetime-affects-placement mechanism, observed rather than believed:

{EXTRACT:demos/next-lab/observations/alerts-seconds-build.txt}

3. Delete `await connection()` from `LastRefreshed`. The build fails with the same sync-IO error shape as the product page — `new Date()` has nowhere to abort. See Mistakes #8 for the recorded product-page form.
4. Point two different sessions at the page and confirm the usage numbers differ. If they don't, a `uid` has leaked into a cached scope — try the module-capture exercise below if you need a reproduction of the uncaught form.

Step 5 is not optional. It is the only test in this list that catches a security bug.

---

## Then vs now

This is the table the repository's [`evolution-ledger`](../../evolution-ledger.md) is built from; most other articles cite one row of it.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Default posture | Cached unless opted out | Dynamic unless opted in | Caching moved from **route classification resolved during build planning** to **per-scope entries with compiler-derived keys**. There is no longer one answer per route to classify, so there is nothing left for a default to guess. |
| Number of caches you reason about | Four overlapping layers with four different opt-outs | One primitive you write, over the layers that remain | The Data Cache and Full Route Cache stopped being the mechanism and became storage details. `'use cache'` is the only surface with an author-facing decision attached. |
| Cache keys | Written by hand: `unstable_cache(fn, ['user', id], opts)` | Derived by the compiler from the build ID and serialized arguments | Key correctness moved from **your discipline** to **the compiler's analysis** — deleting a class of stale-key bugs and creating a new one, because anything read from ambient state at execution time cannot be in the key, and the framework can only stop you when that ambient state is a Next API it recognizes. |
| Lifetime | `export const revalidate = N` on the segment | `cacheLife(profile)` inside the cached scope, with three clocks | A **whole-route declaration** became a **profile on one entry**. One route can hold many entries with different lifetimes, which a segment config could not express — and lifetime now also determines *where* content can be delivered from. |
| Opting out | `dynamic = 'force-dynamic'`, `noStore()`, `cache: 'no-store'` | Nothing; delete them | The opt-outs described a default that no longer exists. `dynamic` and `revalidate` are now build errors rather than no-ops, so the removal is enforced rather than trusted. |
| Persistence | `fetch` Data Cache and `unstable_cache` survived deploys and instances | `'use cache'` is in-memory and build-ID-keyed; durability is opt-in | Storage moved from a framework-managed persistent layer to an in-process default with a pluggable handler. Every deploy now starts cold unless you pay for it not to. |
| Partial Prerendering | `experimental.ppr` + `experimental_ppr` per segment | Removed — it *is* the rendering model | An opt-in experiment became the architecture, which is why there is no flag left to turn on. |
| Finding out you got it wrong | Read the docs, guess, deploy, watch the cache-hit graph | Dev overlay / log / MCP naming the component — and `next build` that may treat the same diagnostic as fatal | Correctness moved from **runtime observation** to **development-time validation**, with the caveat that **dev under-reports severity**: a 200 in `next dev` proves neither correctness nor buildability. |
| Invalidation | `revalidateTag(tag)`; `revalidatePath` | `cacheTag` + `updateTag` (immediate, Server Actions only) or `revalidateTag(tag, profile)` (profile type-required by TypeScript; runtime still accepts a single argument and warns) | Invalidation split along a semantic axis that used to be conflated: read-your-own-writes versus stale-while-revalidate are now different functions rather than the same call with different luck. |

---

## Real-world patterns

**Adopt route by route, not app by app.** The flag goes on, the segment configs come off, and `instant = false` parks anything not ready. A codemod (`cache-components-instant-false`) can apply the opt-out across every page, layout, and default in one pass; you then remove it one route at a time. Note the codemod's failure mode: given a wrong path it reports zero files handled rather than erroring, so check the count.

**Cache the data access, not the route.** `'use cache'` at the top of a page produces one coarse entry keyed by almost nothing, and forbids every runtime read below it. Start at the function that touches the database and move up only with a measured reason.

**Always call `cacheLife` in a cached scope.** Not ceremony — it is what prevents an inner short-lived cache from silently dragging an outer scope's lifetime down, and it is what makes a cached function readable without tracing its callees.

**Tag by entity, not by page.** `cacheTag('product:' + slug)` survives a redesign; `cacheTag('product-page')` does not. The tag should name the thing that changes, and the write that changes it should be the thing that expires it.

**Treat "no invalidating write" as a real answer.** Third-party feeds, aggregate counts, anything you don't own the write path for: time is the only lever, and a tag would be decoration. Say so in a comment so the next reader doesn't add one.

**Measure with `next build && next start`, always.** Dev disables prefetching, behaves differently around cache entries, and under-reports severity for the same diagnostic id. Every caching conclusion in this repository is drawn from a production build (or an explicit `next build` failure).

**Budget for cold caches at deploy.** Because entries are build-ID-keyed and in-memory by default, the first minutes after a release are uncached. Either accept it, or reach for `'use cache: remote'` on the handful of entries where the origin cost is genuinely painful.

---

## API and type reference

| Surface | Import | Role |
| --- | --- | --- |
| `cacheComponents: true` | `next.config.ts` | Enables the model. Requires the Node.js runtime. |
| `'use cache'` | directive | Marks a file, component, or async function as cacheable. In-memory by default. |
| `'use cache: remote'` | directive | Same, backed by a cache handler; durable across instances and deploys. Network round trip. |
| `'use cache: private'` | directive | **Experimental.** Permits runtime APIs; browser-memory only, never stored on the server; unavailable in Route Handlers. |
| `cacheLife(profile)` | `next/cache` | Sets `stale` / `revalidate` / `expire` for the enclosing scope. Cannot be called at module scope. |
| `cacheTag(tag)` | `next/cache` | Attaches an invalidation handle to the enclosing scope. |
| `updateTag(tag)` | `next/cache` | Expires a tag immediately for read-your-own-writes. **Server Actions only.** |
| `revalidateTag(tag, profile)` | `next/cache` | Stale-while-revalidate expiry. Profile is **type-required, runtime-deprecated** without it — see [`tags-and-invalidation`](./tags-and-invalidation.md) for the measured deprecation warning and the traced (not measured) immediate-expiry fallback. |
| `connection()` | `next/server` | Marks the point past which prerendering must stop. Prohibited inside cached scopes. |
| `export const instant = false` | segment config | Allows a segment to block. Does not force dynamic; does not clear sync-IO errors. |
| `cacheHandlers` | `next.config.ts` | Custom storage for `'use cache'` and `'use cache: remote'`. `'use cache: private'` is not configurable. |

---

## Common mistakes

**1. Copying a pre-16 caching idiom that still compiles.** `dynamic` and `revalidate` now error, which is a mercy. The dangerous ones are the `fetch` options and patterns that still run and now mean something else.

**2. `'use cache'` at the top of a page** to make it fast. One coarse entry, no runtime reads permitted below it, and no way to invalidate anything selectively.

{EXTRACT:demos/next-lab/antipatterns/use-cache-on-page.tsx}

**3. Assuming the framework will catch identity in a cached scope.** It catches `cookies()` — at request time, not build time. It cannot catch a module-level variable set by the caller, and it cannot catch an argument that is the same for every user. The key contains the arguments; it does not contain who asked. This is the only mistake on this list that is a security incident.

{EXTRACT:demos/next-lab/lib/billing-leak-b.ts}

**4. Omitting `cacheLife`.** The `default` profile applies, and an inner short-lived cache — possibly in a dependency you didn't write — can drag the scope down. If the outer scope has no explicit lifetime and an inner one is short-lived, you get a prerender error instead, which is the framework doing you a favor loudly.

{EXTRACT:demos/next-lab/antipatterns/missing-cache-life.ts}

**5. Expecting `cacheLife('seconds')` to be prerendered.** Its one-minute `expire` disqualifies it. You asked to cache it; you got a streamed hole with a server cache in front. Usually correct — but know it happened.

**6. Assuming cache entries survive a deploy.** Build-ID-keyed and in-memory. Migrating off `unstable_cache` or the Data Cache, this shows up as a post-release cost spike.

**7. Trusting a 200 in `next dev`.** The diagnostic is absent from the HTTP response *and* may be fatal at `next build`. Dev under-reports severity — a passing page proves neither correctness nor buildability.

{EXTRACT:demos/next-lab/observations/insight-vs-build-error.txt}

**8. Reaching for `instant = false` at a synchronous-IO error.** It is a latency opt-out and that is a correctness failure. `new Date()` in a prerendered path needs `connection()` behind a boundary, or a Client Component.

{EXTRACT:demos/next-lab/observations/sync-io-error.txt}

**9. Tagging the page instead of the entity.** `cacheTag('dashboard')` invalidates everything or nothing. Tag what changed.

{EXTRACT:demos/next-lab/antipatterns/page-tag.ts}

**10. Treating adoption as a migration you finish in one PR.** The route-at-a-time loop exists because the classification work — deciding which of four answers each read gets — is the actual cost, and it is per-feature, not per-repo.

---

## Exercises

**1. Classify before you code.** Take one route in an existing app and fill in the Step 2 table for every data read: same for everyone, invalidating write, chosen answer. Do not write code. If any row's "invalidating write" column is empty and you still wrote "cache it," change it.

*Hint: aggregate counts and third-party feeds are the rows that expose the habit.*

**2. Watch a lifetime move an answer.** In the walkthrough app, flip `getAlerts` between `cacheLife('minutes')` and `cacheLife('seconds')` and compare `.next/server/app/dashboard.html` each time — not the response body.

*Hint: what you're looking for is the alert banner appearing in, then disappearing from, the prerender artifact. `curl` will show the alert either way because it follows the stream.*

**3. Build the leak, then fix it.** Add a module-level `let lastSeenUid` to `lib/billing.ts`, set it from the uncached `Usage` component, and read it inside the cached function instead of taking `uid` as an argument. Build, start, then request the page twice with different `uid` cookies.

*Hint: `UsageChart` renders `data-uid`. If both requests return the same one, you have reproduced it. Recorded against the dedicated leak routes:

{EXTRACT:demos/next-lab/observations/leak-bc-curl.txt}

Then try the same thing with `cookies()` inside the cached function and note that you get an error instead — the framework catches one form and not the other, and knowing which is which is the point.*

---

## Summary

- One decision inverts one default: **nothing is cached unless `'use cache'` says so.**
- The inversion happened because four implicit layers made "is this cached?" unanswerable by reading your own code.
- Every read gets one of four answers: **cache, stream, block, push to the client**. If you can't name the invalidating write, it isn't "cache."
- Lifetime is not just TTL. Short enough `expire` or `stale` removes content from the prerender, quietly converting "cache it" into "stream it."
- Keys are compiler-derived from the build ID and the serialized arguments. Anything read from ambient state at execution time cannot be in the key — and the framework can only stop you when that ambient state is a Next API it recognizes. The argument must identify the data.
- `'use cache'` is in-memory and build-ID-keyed. Every deploy starts cold unless you opt into durable storage.
- Validation is part of the model. Diagnostics are absent from the HTTP response, and the same id can be advisory in `next dev` and fatal in `next build`. A 200 in dev proves neither correctness nor buildability.

---

## See also

- [`foundations/thinking-in-the-app-router`](../foundations/thinking-in-the-app-router.md) — the shell/hole rendering model this caching model sits inside
- [`caching/use-cache-directive`](./use-cache-directive.md) — exactly what enters a compiler-derived key
- [`caching/cache-lifetimes`](./cache-lifetimes.md) — the three clocks, profiles, and nesting rules in full
- [`caching/tags-and-invalidation`](./tags-and-invalidation.md) — `updateTag` vs `revalidateTag` vs `revalidatePath`
- [`caching/the-other-cache-layers`](./the-other-cache-layers.md) — what survived from the four-layer model
- [`data/runtime-data-and-cached-scopes`](../data/runtime-data-and-cached-scopes.md) — the read-outside-pass-in rule and its failure mode
- [`migration/adopting-cache-components`](../migration/adopting-cache-components.md) — the route-at-a-time loop at real scale

---

## References

- Next.js — `next.config.js: cacheComponents`
- Next.js — Getting Started: Caching
- Next.js — Guides: Migrating to Cache Components
- Next.js — Directives: `use cache`, `use cache: remote`, `use cache: private`
- Next.js — Functions: `cacheLife`, `cacheTag`, `updateTag`, `revalidateTag`, `connection`
- Next.js — `next.config.js: cacheHandlers`, `staleTimes`
- Next.js — Guides: Instant Navigation
- Next.js blog — Next.js 16 (2025-10-21), Next.js 16.3 (2026-08-03)

---

## Demo source

Extracted from:

- `demos/next-lab/next.config.ts`
- `demos/next-lab/app/basic/page.tsx`
- `demos/next-lab/app/dashboard/page.tsx` (+ `parts.tsx`)
- `demos/next-lab/legacy/dashboard-page.next15.tsx`
- `demos/next-lab/lib/billing.ts`, `lib/status.ts`, `lib/billing-leak-{a,b,c}.ts`, `lib/db.ts`
- `demos/next-lab/app/leak-{a,b,c}/`
- `demos/next-lab/antipatterns/` (`use-cache-on-page.tsx`, `missing-cache-life.ts`, `page-tag.ts`)
- `demos/next-lab/observations/` (`sync-io-error.txt`, `leak-a-runtime-error.txt`, `leak-bc-curl.txt`, `alerts-minutes-build.txt`, `alerts-seconds-build.txt`, `insight-blocking-prerender.txt`, `insight-vs-build-error.txt`)
- `demos/next-lab/app/insight-probe/` (insight measurement; ships with `instant = false`)

> **Verification status.** Verified against `next@16.3.0` (docs + demo). **Measured (extracted):** sync-IO prerender error; alerts leave `.next/server/app/dashboard.html` under `cacheLife('seconds')` while `minutes` keeps them; leak A runtime throw with digest; leaks B/C via `data-uid`; `blocking-prerender-dynamic` HTTP 200 in `next dev` and fatal in `next build` without `instant = false` / boundary (`insight-vs-build-error.txt` — severity-ladder claim falsified and rewritten). **Traced:** three-clock profiles and prerender-exclusion thresholds; nested-lifetime rules; `updateTag` Server-Action-only; `instant = false` neither forces dynamic nor clears sync-IO; codemod wrong-path `0 ok`. **Corrected (session 15):** `revalidateTag`'s profile argument is **type-required, runtime-deprecated** — not a runtime requirement — per the measured deprecation warning in [`tags-and-invalidation`](./tags-and-invalidation.md). **Pending:** DevTools MCP / overlay confirmation of the same surface (log-only so far); nothing else for this article's claims. Code blocks are extracted via `scripts/build-article.py`; this file is `status: review`.
