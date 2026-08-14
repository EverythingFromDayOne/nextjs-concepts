---
article_id: use-cache-directive
concept_folder: caching
wave: 2
related:
  - caching/cache-components-model
  - caching/cache-lifetimes
  - caching/tags-and-invalidation
  - foundations/rules-of-the-server-boundary
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-11
status: draft
---

# The `'use cache'` directive

> **Lead with this.** Everything about this directive reduces to one question: **what is in the key?**
>
> The answer is the build ID and the function's serialized arguments. Not the request. Not the session. Not anything the function reaches for while it runs. Every rule below — why it must be async, why runtime APIs are rejected, why entries vanish on deploy, why a leak is possible at all — falls out of that one sentence.

---

## What it is

A directive that marks work as reusable. Next.js stores the result and replays it for subsequent calls that produce the same key.

Three positions:

{DIRECTIVE_POSITIONS_RESULT}

The most useful of the three is the **function** form, on the function that touches your data source:

{EXTRACT:demos/next-lab/lib/catalog.ts#getProduct}

Three things are load-bearing here, and the directive is only one of them. `slug` is an argument, so it distinguishes entries. `cacheTag` gives the write side a handle. `cacheLife` bounds staleness — and, as [`cache-lifetimes`](./cache-lifetimes.md) shows, also decides whether the entry can be prerendered at all.

---

## How it works under the hood

### The key, measured

The compiler derives a key from the build ID and the serialized arguments. What "serialized" means in practice is worth knowing precisely, because it decides your hit rate:

{KEY_COMPOSITION_RESULT}

Read the array row carefully. Two calls with the same values in a different order either share an entry or don't, and that single fact determines whether sorting before a cached call is a style preference or a cache-hit-rate decision.

### What is *not* in the key

Anything the function reaches for while it runs.

That is the entire source of the most dangerous bug in this model. A cached function has no idea who is asking, so identity read from ambient state — a module variable, a singleton, an SDK's configured context — is invisible to the key:

{EXTRACT:demos/next-lab/lib/billing-leak-b.ts}

Next.js guards the version of this that touches an API it recognises. Reading `cookies()` inside a cached scope is rejected. It cannot guard a module-level variable, because there is nothing about that code to detect. Full treatment, including a third form that leaks *with* an argument, in [`user-a-sees-user-b-data`](../../recipes/caching/user-a-sees-user-b-data.md).

The rule that survives contact with all three forms:

> **The argument must identify the data.** Passing an argument isn't the point; passing one that distinguishes the result is.

### Why it must be async

The directive marks a boundary the framework can suspend at. A synchronous function has no suspension point, so there is nowhere to insert the cache lookup:

{EXTRACT:demos/next-lab/antipatterns/non-async-cached-fn.ts}

The same reasoning explains why runtime APIs are rejected inside a cached scope and why `connection()` is prohibited there: a cache entry that depends on the connection has no reuse. See the enforcement matrix in [`rules-of-the-server-boundary`](../foundations/rules-of-the-server-boundary.md), including *when* each of those is caught — which depends on route shape, not on the violation.

### The build ID, and what a deploy costs you

{BUILD_ID_RESULT}

This is the operational consequence teams plan around. The `fetch` Data Cache and `unstable_cache` both persisted across deploys; `'use cache'` defaults to in-memory storage and is keyed per build. Migrating from either, the first minutes after each release are uncached — a cost spike rather than a bug report.

Durable storage exists: `'use cache: remote'` or a configured cache handler, at the price of a network round trip on every check. That's [`remote-caches-and-durability`](./remote-caches-and-durability.md).

### Composition passes through

A cached component does not cache what it is *given*. `children` and element props were rendered elsewhere and arrive as output:

```tsx
async function CachedFrame({ children }: { children: React.ReactNode }) {
  'use cache'
  cacheLife('hours')
  const chrome = await getChrome()
  return <div className={chrome.className}>{children}</div>
}
```

The frame is cached; the children are whatever the caller rendered. That's what makes it safe to wrap uncached, per-request content in a cached shell — and it's the mechanism [`composition-and-cache-boundaries`](./composition-and-cache-boundaries.md) is built on.

### A Server Action's render does not populate the cache

When a Server Action returns and Next.js re-renders the page for that response, cached functions called during that render execute for real — and their results are not stored. The next reader gets a miss, or the pre-existing entry, depending on how the tag was invalidated.

This explains a class of "why is it still recomputing" confusion after a mutation: the work you watched happen was throwaway. Measured with an instrumented compute counter on `getPlans()` (incremented on every real execution, carried through the cached return so a hit replays the miss's count): under both `updateTag` and `revalidateTag`, the action's own re-render bumped the counter — a real, uncached miss — and that computation was never reused by the request that followed. See [`tags-and-invalidation`](./tags-and-invalidation.md) for the two invalidation paths and what each next reader gets instead.

### Cache the access, not the route

The commonest overreach is putting the directive at the top of a page:

{EXTRACT:demos/next-lab/antipatterns/use-cache-on-page.tsx}

One coarse entry keyed by almost nothing, and every runtime read below it becomes illegal. Start at the function that touches the data source and move up only with a measured reason.

### Always call `cacheLife`

Not ceremony:

{EXTRACT:demos/next-lab/antipatterns/missing-cache-life.ts}

Without an explicit lifetime, an inner cached function with a *shorter* one can drag the outer scope down — and the inner cache may be in a dependency you never opened. Next.js throws during prerendering rather than letting that happen silently, which means the error is often the first you hear of a nested cache existing at all.

---

## Basic usage

{EXTRACT:demos/next-lab/lib/billing.ts#getPlans}

Cached, tagged, and bounded. Everything else is a variation on those three lines.

---

## Walkthrough — taking one query from uncached to correctly cached

### Step 1 — start uncached, and know why

{EXTRACT:demos/next-lab/lib/inventory.ts#getLiveStock}

No directive, deliberately. Inventory that is thirty seconds stale sells things you don't have. **Uncached is a decision, not a default you failed to change** — and if you can't name the write that invalidates a value, uncached is usually the right one.

### Step 2 — add the directive to the access, not the caller

{EXTRACT:demos/next-lab/lib/catalog.ts#getProduct}

The function that touches the data source. Not the component, not the page.

### Step 3 — make the argument identify the data

`slug` distinguishes one product from another, so one entry per product. Test the argument against the question *could two different results share this key?* If yes, the argument is too coarse.

### Step 4 — bound the staleness

`cacheLife('hours')` is a ceiling, not a promise — tag invalidation still wins. Choose it by asking how wrong the value is allowed to be, then read [`cache-lifetimes`](./cache-lifetimes.md), because a short enough lifetime changes where the content can be delivered from.

### Step 5 — give the write side a handle

`cacheTag('product:' + slug)` names the *entity*, not the page. A tag naming a page survives until the page is redesigned; a tag naming a product survives as long as products do.

### Step 6 — verify

```bash
pnpm build && pnpm start
```

1. Request the same product twice and confirm the second is a hit — the artificial delay in `lib/db.ts` gives you the signal.
2. Request a different product and confirm it is a miss. Same key would mean the argument isn't distinguishing.
3. Rebuild without changing source, restart, request again. See the build-ID result above for what to expect.
4. If the data is per-user, run the two-cookie test from the leak recipe. Nothing in the tooling catches that class.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 2, 5, 6.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Declaring a cache | `unstable_cache(fn, keyParts, opts)` — a wrapper you called | `'use cache'` — a directive inside the function | Caching moved from a **higher-order function you composed** to a **compiler-recognised marker**, which is what lets the key be derived rather than declared. |
| Writing keys | By hand, in an array you had to keep in sync with the arguments | Derived from the serialized arguments | Key correctness moved from **your discipline** to **static analysis** — deleting a class of stale-key bugs and creating a new one, since anything read at execution time is invisible to it. |
| Caching `fetch` | `fetch(url, { cache, next: { revalidate, tags } })` per call | Wrap the fetch in a cached scope; options move to `cacheLife` / `cacheTag` | Configuration moved from **per-call options on one API** to **per-scope declarations**, so caching stopped being a property of `fetch` specifically and became a property of any work. |
| Persistence | Data Cache and `unstable_cache` survived deploys and instances | Build-ID-keyed, in-memory by default | Storage moved from a framework-managed persistent layer to an in-process default with a pluggable handler. |
| Opting out | `cache: 'no-store'`, `noStore()`, `fetchCache` | Nothing — uncached is the default | The opt-outs described a default that no longer exists. |

---

## Real-world patterns

**One cached function per data access, named for what it fetches.** `getProduct(slug)` and `getProductsByIds(ids)`, not `getCatalogData(opts)`. Coarse functions produce coarse keys.

**Normalise arguments before the call, deliberately.** Sort arrays, canonicalise objects, round timestamps. Whether that's necessary is answered by the key-composition result above — but doing it consciously is free and makes the hit rate legible.

**Never pass an object where two fields would do**, unless you've confirmed how object arguments serialize. Primitives have obvious key behaviour; objects have measured behaviour.

**Read identity outside, and check that the argument distinguishes.** Two separate checks. The second is the one people skip.

**Call `cacheLife` every time.** It's what prevents an inner cache from silently dragging your lifetime down, and it makes a cached function readable without tracing its callees.

**Tag entities, not pages.** The tag should name the thing that changes and the write that changes it.

**Budget for cold caches at every deploy**, or move the expensive entries to `'use cache: remote'`.

---

## API and type reference

| Surface | Where | Notes |
| --- | --- | --- |
| `'use cache'` | file, function, or component | Must be async. In-memory, build-ID-keyed by default. |
| `'use cache: remote'` | same positions | Durable via a cache handler; network round trip per check. |
| `'use cache: private'` | same positions | **Experimental.** Permits runtime APIs; measured as providing no server-side caching — see [`remote-caches-and-durability`](./remote-caches-and-durability.md). |
| `cacheLife(profile)` | inside a cached scope | Cannot be called at module scope. |
| `cacheTag(tag)` | inside a cached scope | Invalidation handle. |
| `cacheHandlers` | `next.config.ts` | Custom storage for `'use cache'` and `'use cache: remote'`. |

---

## Common mistakes

**1. Reading ambient state inside a cached scope.** The key holds arguments. `cookies()` there is rejected; a module variable is not, and leaks.

**2. An argument that doesn't distinguish the result.** Passing `scope: 'signed-in'` is passing an argument. Every signed-in user shares one entry.

**3. The directive at the page root.** One coarse entry, and no runtime reads permitted below it.

**4. Omitting `cacheLife`.** An inner short-lived cache — possibly in a dependency — drags the scope down, or throws during prerendering.

**5. A non-async cached function.** No suspension point to insert the lookup at.

**6. Assuming entries survive a deploy.** See the measured result above.

**7. Tagging the page instead of the entity.** Invalidates everything or nothing.

**8. Caching something you can't invalidate.** If no write in your system changes it, a tag is decoration and time is the only lever. Say so in a comment.

**9. Caching cheap per-user data.** One entry per user is N entries and a security surface. Streaming it uncached is often better.

---

## Exercises

**1. Audit an argument.** For each `'use cache'` in your app, ask: *could two different results share this key?* Anywhere the answer is yes, you have either a bug or an entry doing nothing.

**2. Measure a hit.** Add a counter to a cached function, call it twice with equal arguments and once with different ones, and confirm the counts move as you expect. Then try structurally-equal-but-differently-ordered arguments and compare against the measured result above.

**3. Find an unbounded scope.** Grep for `'use cache'` without a nearby `cacheLife`. Each one is inheriting a default and is vulnerable to being dragged down by a callee.

---

## Summary

- The key is the **build ID and the serialized arguments**. Everything else follows.
- Anything read at execution time is **not** in the key. The framework guards the APIs it recognises and nothing else.
- **The argument must identify the data** — passing one is not sufficient.
- Cached functions must be async, because the directive marks a suspension point.
- Entries are build-ID-keyed and in-memory by default, so a deploy starts cold.
- `children` passes *through* a cached component uncached.
- A Server Action's re-render is a real computation that is never stored — the next reader gets a miss or the pre-existing entry, never the writer's render.
- Cache the data access, not the route. Always call `cacheLife`. Tag entities, not pages.

---

## See also

- [`caching/cache-components-model`](./cache-components-model.md) — why the default inverted
- [`caching/cache-lifetimes`](./cache-lifetimes.md) — the three clocks, and how lifetime decides placement
- [`caching/tags-and-invalidation`](./tags-and-invalidation.md) — `updateTag` vs `revalidateTag`
- [`caching/composition-and-cache-boundaries`](./composition-and-cache-boundaries.md) — what passes through a cached component
- [`foundations/rules-of-the-server-boundary`](../foundations/rules-of-the-server-boundary.md) — what's legal in a cached scope, and when it's caught
- [`user-a-sees-user-b-data`](../../recipes/caching/user-a-sees-user-b-data.md) — the leak class in full

---

## References

- Next.js — Directives: `use cache`, `use cache: remote`, `use cache: private`
- Next.js — Functions: `cacheLife`, `cacheTag`, `connection`
- Next.js — Guides: Migrating to Cache Components
- Next.js — `next.config.js: cacheComponents`, `cacheHandlers`

---

## Demo source

`demos/next-lab/lib/catalog.ts`, `lib/billing.ts`, `lib/inventory.ts`, `lib/billing-leak-b.ts`, `lib/key-probe.ts`, the three files in `demos/next-lab/antipatterns/` named above, and the capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0`. **Three claims this article makes were shipped in earlier articles and never measured until this session**: whether argument order affects the key (asserted in a `lib/catalog.ts` comment written in session 3 and extracted into article 1); whether the build ID is genuinely in the key such that entries do not survive a deploy (asserted in articles 1 and 6); and whether all three directive positions work as described, including a file-level export called directly from a Client Component. Any of the three coming back differently corrects an earlier article, not just this one. **Added in a later correction pass, not part of this session's original plan:** the "Server Action's render does not populate the cache" property above was discovered while investigating article 11's tag-invalidation behavior, not predicted going in. An instrumented compute counter on a cached function is what settled it — timing evidence alone couldn't distinguish a stored hit from a coincidentally-fast recompute. Every code block is extracted.
