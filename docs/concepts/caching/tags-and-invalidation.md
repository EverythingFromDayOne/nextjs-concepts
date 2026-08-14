---
article_id: tags-and-invalidation
concept_folder: caching
wave: 2
related:
  - caching/use-cache-directive
  - caching/cache-lifetimes
  - mutations/closing-the-loop
  - caching/composition-and-cache-boundaries
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-14
status: draft
---

# Tags and invalidation

> **Lead with this.** A lifetime says how wrong a value may get. A **tag** says who is allowed to make it right again — and Next.js 16 split that into two functions because "make it right" means two different things.
>
> The writer isn't part of this decision. Both functions render fresh data in the action's own response, and neither stores it. What you're choosing is what happens to **the next person to load the page**: `updateTag` makes them wait for a fresh computation; `revalidateTag` hands them the pre-write value instantly and refreshes behind them. **`updateTag` buys correctness with latency. `revalidateTag` buys latency with staleness.** Choosing wrong produces a bug with no error attached: the save looks fine, and the *next* load looks like it didn't happen.

---

## What it is

Three pieces:

| Surface | Where it goes | What it does |
| --- | --- | --- |
| `cacheTag(tag)` | inside a cached scope | Labels the entry so something can expire it later |
| `updateTag(tag)` | inside a Server Action | Expires immediately — the caller sees fresh data |
| `revalidateTag(tag, profile)` | server-side | Marks stale — the next reader may still get the old value |

Tagging is cheap and unconditional. The interesting decision is which invalidation function fires on a write.

---

## How it works under the hood

### The measured difference

Both functions expire an entry. What separates them is what happens **after** the write — measured on `/tags` with a warm `'use cache'` read tagged `plans` (second GET ≪ the 180ms db delay before each write):

| function | before | action response | next request |
| --- | --- | --- | --- |
| `updateTag` | 2900 | **3100** (new) | **3100** (new; ~199ms miss) |
| `revalidateTag(…, 'max')` | 2900 | **3300** (new) | **2900** (old; ~5ms hit), then 3300 |

Under progressive-enhancement form POST, **both** action-response HTML bodies rendered the new price. The SWR distinction showed up on the **next GET**: `revalidateTag(..., 'max')` still served the warm stale entry (2900, fast); a following GET then showed 3300. `updateTag` made the next GET a blocking recompute (3100, slow).

A follow-up instrumented run pinned down *why* both action responses agree: a module-level compute counter added to `getPlans()` — incremented on every real execution, and baked into the cached return so a hit replays the miss's count — showed the action's own re-render bumping the counter under **both** functions. That render is a real, uncached computation, and it is discarded either way; **a Server Action's re-render does not populate the cache** (see [`use-cache-directive`](./use-cache-directive.md) for this as a general property, not one specific to tags). The counter also settled the propagation question below: the 1st GET's 2900 after `revalidateTag` carried the *same* count as the pre-write warm read — an older entry that survived the action's computation, not a coincidentally-fast recompute — while `updateTag`'s 1st GET carried a *higher* count than the action's, a fresh miss of its own.

So the two functions are not identical — but the divergence is not "middle column of the action response" for this request shape. It is whether the **subsequent** read is allowed to stay stale. That is still the difference between a UI that settles on the write and a UI that flickers old → new (or looks like the save failed if you only watch the first reload).

The reason this needed two functions rather than one flag: the two behaviours have opposite failure modes. Immediate expiry makes the writer wait for a fresh computation. Stale-while-revalidate can make a follow-up read look like the write didn't land. Neither is safe as a default, so Next.js made you pick.

### Where each is allowed

Measured against the claims shipped (as traced, not measured) in [`cache-components-model`](./cache-components-model.md) and [`rules-of-the-server-boundary`](../foundations/rules-of-the-server-boundary.md):

| Claim | Phase | Result |
| --- | --- | --- |
| `updateTag` from a Route Handler | **runtime** | Throws: `updateTag can only be called from within a Server Action…` |
| `updateTag` from a Server Component render | **runtime** (build OK with `instant = false`) | Throws the render-phase guard: `used "updateTag …" during render which is unsupported` — not the same string as the RH error, but still a hard failure |
| `revalidateTag('plans')` with no profile | **typecheck / `next build`** | `TS2554: Expected 2 arguments, but got 1` |
| same single-arg call at runtime (types suppressed) | **runtime** | **Accepted** — HTTP 200 — with a deprecation warning asking for `"max"` or `updateTag` |

**Contradiction to name explicitly:** articles 6 and 9 say the profile argument is required. Corrected here: it's **type-required, runtime-deprecated** — true for TypeScript / `next build` (`TS2554`), not a runtime throw today. The runtime warning, verbatim:

```text
"revalidateTag" without the second argument is now deprecated, add second
argument of "max" or use "updateTag". See more info here:
https://nextjs.org/docs/messages/revalidate-tag-single-arg
```

**Traced, not measured** (docs + `next@16.3.0` source — not exercised as a separate probe here): a missing profile does not fall back to `'max'`-style stale-while-revalidate. It takes the same immediate-expiry path as `updateTag`. That cuts against the intuition "omitting the argument defaults to the gentler behavior" — omitting it gets you `updateTag` semantics, the *less* forgiving of the two.

The restriction on `updateTag` follows from what it promises. Read-your-own-writes only means something when there *is* a write and a caller waiting on it — which is the shape of a Server Action and not of a Server Component rendering a page.

### Granularity and propagation

Three measurements, all against `next@16.3.0` with runtime reads (`await connection()` so prerendered HTML cannot mask hits). Tag expiry used `{ expire: 0 }` where a miss/hit timing signal was required — `profile: 'max'` would SWR-serve stale and hide the miss.

1. **Granularity.** `getProduct('aeron-chair')` and `getProduct('standing-desk')` warm in ~0.3–0.9ms each. After `revalidateTag('product:aeron-chair', { expire: 0 })`, aeron missed (~122ms) and desk stayed a hit (~0.9ms). Per-slug tags are independent.

2. **Propagation.** An outer `'use cache'` scope tagged `outer` calling an inner scope tagged `inner`. After warming, bumping an inner stamp and `revalidateTag('inner', { expire: 0 })`, the **next read of outer** was a ~182ms miss with the new inner stamp and a new `outerGeneratedAt`. Invalidating the inner tag refreshed the outer entry too — the outer entry does **not** keep serving a result built from stale inner data. Likely mechanism: composing an inner cached call collects the inner tag onto the outer entry, so expiring `inner` expires outer as well. (Control: expiring only `outer` recomputes outer in ~1ms while reusing a warm inner hit — the entries are distinct; the tag sets overlap via composition.)

3. **`revalidatePath`.** Warm `getPlans()` (tag `plans`) at 2900. Write the store to 4400 and call `revalidatePath('/tag-path-probe')` with **no** tag invalidation. The tagged read stayed 2900 on a fast hit; the path's HTML still showed 2900. Control: `revalidateTag('plans', { expire: 0 })` then returned 4400 on a ~181ms miss. **`revalidatePath` does not invalidate tagged entries** — it is not a substitute for the tag that names the write.

**Contradiction to name explicitly:** the draft assumption that "invalidating an inner tag leaves an outer entry stale" was **falsified**. The composition hazard to teach is the opposite direction people forget: expiring an inner tag can invalidate every outer scope that called it, not that outer silently keeps stale inner data.

### Tags name entities, not pages

`cacheTag('product:' + slug)` survives a redesign. `cacheTag('product-page')` survives until someone splits the page in two.

The test: **name the write that fires this tag.** If you can describe it — "an admin edits this product" — the tag is at the right granularity. If the answer is "several unrelated things," the tag is too coarse and every one of them will invalidate the others' work.

<!-- extract: demos/next-lab/lib/catalog.ts#getProduct -->
```ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

export async function getProduct(slug: string) {
  'use cache'
  cacheLife('hours')
  cacheTag(`product:${slug}`)
  return db.products.findBySlug(slug)
}
```

One entry per product, one tag per product, and the write that changes a product expires exactly that entry.

### When a tag is the wrong tool

Not everything has a write you control:

<!-- extract: demos/next-lab/lib/status.ts -->
```ts
import { cacheLife } from 'next/cache'
import { db } from './db'

/**
 * No cacheTag, deliberately: nothing in our system can invalidate a third
 * party's status feed, so a tag would be decoration. Time is the only
 * honest lever.
 *
 * cacheLife('minutes') keeps this in the prerender. 'seconds' would not —
 * its one-minute expire falls under the exclusion threshold.
 */
export async function getAlerts() {
  'use cache'
  cacheLife('minutes')
  return db.alerts.findMany()
}
```

No tag, deliberately. Nothing in this system can invalidate a third party's status feed, so a tag would be decoration and time is the only honest lever. Worth a comment, so nobody adds one later out of symmetry.

### Long lifetime plus tag beats short lifetime

The pairing that makes caching worth doing. A short lifetime is polling: it guesses at the write, misses it by up to the interval, and — per [`cache-lifetimes`](./cache-lifetimes.md) — may cost you the prerender. A long lifetime with a tag is precise: correct within milliseconds of the write, and prerenderable in between.

If you find yourself shortening a lifetime to make data fresher, the question to ask is what write you're waiting for and whether you can tag it instead.

---

## Basic usage

<!-- extract: demos/next-lab/lib/billing.ts#getPlans -->
```ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

export async function getPlans() {
  'use cache'
  cacheLife('days')
  cacheTag('plans')
  return db.mutablePlans.findMany()
}
```

Tagged on the read. The write side:

<!-- extract: demos/next-lab/app/tags/actions.ts -->
```ts
'use server'

import { updateTag, revalidateTag } from 'next/cache'
import { db } from '@/lib/db'

export async function setPriceWithUpdate(formData: FormData) {
  await db.mutablePlans.setPrice(String(formData.get('id')), Number(formData.get('cents')))
  updateTag('plans')
}

export async function setPriceWithRevalidate(formData: FormData) {
  await db.mutablePlans.setPrice(String(formData.get('id')), Number(formData.get('cents')))
  revalidateTag('plans', 'max')
}
```

Both actions do the same write and render the new price in their own response either way. They differ only in what the *next* request to load the page gets back.

---

## Walkthrough — closing the loop on one mutation

### Step 1 — tag the read

Per entity, named for the thing that changes. `plans` here because a plan edit affects the whole table; `product:${slug}` where one row changes at a time.

### Step 2 — write, then invalidate, in that order

The write has to land before the invalidation, or you expire an entry and immediately rebuild it from the old data. That is a real race and it produces a bug that reproduces about half the time.

### Step 3 — choose the function by what the next reader can afford

Not by who is looking — the writer sees fresh data in the action's own response either way, so that's not the decision. Ask what the **next** person to load the page can afford:

**Can't afford staleness** → `updateTag`. The next request pays a real recomputation, but it's guaranteed current.

**Can afford a moment of staleness in exchange for speed** → `revalidateTag`. The next request gets the pre-write value instantly, and a fresh one lands behind it.

In practice this usually lands on the same calls as "who is looking" — a Server Action the user is about to reload still tends to want `updateTag` — but derive the answer from the next reader's tolerance, not the writer's identity. That's the version that survives composition: a webhook-triggered write and a user-triggered write should get the same function if their readers have the same tolerance for staleness, and "who triggered it" doesn't tell you that.

### Step 4 — verify the loop

```bash
pnpm build && pnpm start
```

1. Load the page, note the value, confirm a second load is a cache hit — the artificial delay is the signal. **The entry must be warm before you write**, or you'll be measuring a cold miss and both functions will look identical.
2. Submit the `updateTag` form. Check the response *to that submission*.
3. Reload. Check again.
4. Repeat with the `revalidateTag` form.
5. Compare against the measured table above.

Step 1 is the one that invalidates the whole experiment if you skip it.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 5, 11.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Tagging | `fetch(url, { next: { tags: [...] } })` — a property of one fetch | `cacheTag(tag)` inside a cached scope | Tagging stopped being a `fetch` option and became a property of any cached work, so anything cacheable is now taggable. |
| Invalidation | `revalidateTag(tag)` — one function, one behaviour | `updateTag(tag)` and `revalidateTag(tag, profile)` | A distinction that was **conflated** got split along a semantic axis. Read-your-own-writes and stale-while-revalidate were the same call with different luck; they are now different functions, and choosing is mandatory. |
| The profile argument | Didn't exist | Required on `revalidateTag` | Expiry gained a lifetime dimension, so "how stale may the replacement be" became part of the invalidation call rather than only of the original scope. |
| Path invalidation | `revalidatePath(path)` against the Full Route Cache | Same name; the Full Route Cache it targeted is gone | The route-level cache it was designed for was replaced by per-scope entries, so its relationship to tagged data changed — see the measured result above. |

---

## Real-world patterns

**Tag on the read, invalidate on the write.** Both halves in the same PR, or the tag is decoration.

**Name the write before you name the tag.** If you can't describe the write in one sentence, the tag is too coarse.

**Default to `updateTag` in Server Actions and `revalidateTag` everywhere else.** The exception is a Server Action whose result the user doesn't look at — a background enqueue, a fire-and-forget log.

**Invalidate after the write completes.** Awaiting the write first is not a style preference; it's the difference between an expiry and a race.

**Prefer long lifetime plus tag over short lifetime.** Precise beats frequent, and it keeps you above the prerender thresholds.

**Say when a tag is wrong.** Third-party data with no write you control gets a comment explaining the absence.

**Check tags consumed inside other cached scopes.** Expiring an inner tag refreshes composers that called it — that can be more invalidation than you meant.

---

## API and type reference

| Surface | Import | Notes |
| --- | --- | --- |
| `cacheTag(tag)` | `next/cache` | Inside a cached scope. Multiple tags per scope allowed. |
| `updateTag(tag)` | `next/cache` | Server Actions only — see the measured restriction above. |
| `revalidateTag(tag, profile)` | `next/cache` | Stale-while-revalidate. Profile is type-required (TypeScript), runtime-deprecated without it. |
| `revalidatePath(path)` | `next/cache` | Route-level. Interaction with tagged entries measured above. |

---

## Common mistakes

**1. `revalidateTag` in a Server Action the user is watching.** The write lands, the response shows the old value, the user presses save again. `updateTag` is the fix.

**2. Reading the new → old → new sequence as a bug.** Under `revalidateTag`, a writer can watch the value go new → old → new: the action response shows their edit, the next navigation shows the pre-write value, and a later load shows the edit again. Nothing is broken. They saw a render that was never cached, then rejoined everyone else's timeline.

**3. Invalidating before the write completes.** Expire, rebuild from old data, and the new value is gone. Reproduces intermittently, which makes it expensive to find.

**4. Tagging the page.** `cacheTag('dashboard')` invalidates everything or nothing.

**5. Tagging data you can't invalidate.** A tag on a third-party feed is decoration.

**6. Shortening a lifetime instead of adding a tag.** Polling, plus a possible loss of the prerender.

**7. Assuming `revalidatePath` covers tagged data.** Measured: the path re-rendered and still embedded the warm tagged `plans` value until `revalidateTag` / `updateTag` ran.

**8. Only tagging the reads you remember.** One untagged read of the same data means a page that's fresh in one place and stale in another, with no error.

---

## Exercises

**1. Name the write.** For every `cacheTag` in your app, write the sentence describing the write that fires it. Any tag without a sentence is either miscalibrated or unnecessary.

**2. Reproduce the wrong choice.** Swap `updateTag` for `revalidateTag` in a Server Action and use the form as a user would. The bug you get is the one your users would report as "save doesn't work."

**3. Audit for untagged siblings.** Find data read in more than one cached scope and confirm every one carries the tag. The odd one out is a page that goes stale silently.

---

## Summary

- A lifetime bounds staleness; a **tag** says who can end it early.
- The writer isn't part of the decision — both functions render fresh data in the action's own response. What you're choosing is what the **next reader** gets: `updateTag` makes them wait for a fresh computation; `revalidateTag` hands them the pre-write value and refreshes behind them.
- `updateTag` is **read-your-own-writes** and is restricted to Server Actions. `revalidateTag` is **stale-while-revalidate**; its profile argument is type-required by TypeScript (runtime still accepts single-arg with a deprecation warning, and — traced, not measured — a missing profile behaves like `updateTag`'s immediate expiry, not like `'max'`).
- The measured difference under form POST: both action responses showed the new value; **`revalidateTag(..., 'max')` still served the old value on the next GET** while `updateTag` did not. An instrumented compute counter confirmed the mechanism: the action's re-render is a real, discarded miss under both functions.
- Tags name **entities**, not pages. The test is whether you can name the write.
- **Long lifetime plus a tag** beats a short lifetime: precise instead of polling, and it stays above the prerender thresholds.
- Invalidate **after** the write lands, or you rebuild from stale data.
- `revalidatePath` does not drop tagged entries; tag invalidation is still required for the write to show up.

---

## See also

- [`caching/use-cache-directive`](./use-cache-directive.md) — where `cacheTag` goes and what it labels
- [`caching/cache-lifetimes`](./cache-lifetimes.md) — the ceiling a tag lets you raise
- [`caching/composition-and-cache-boundaries`](./composition-and-cache-boundaries.md) — nested scopes and propagation
- [`mutations/closing-the-loop`](../mutations/closing-the-loop.md) — the mutation-side view of the same problem
- [`mutations/server-functions`](../mutations/server-functions.md) — where `updateTag` is allowed to live

---

## References

- Next.js — Functions: `cacheTag`, `updateTag`, `revalidateTag`, `revalidatePath`
- Next.js — Directives: `use cache`, `use server`
- Next.js — Guides: Migrating to Cache Components

---

## Demo source

`demos/next-lab/lib/catalog.ts`, `lib/billing.ts`, `lib/status.ts`, `lib/db.ts`, `demos/next-lab/app/tags/`, and the capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0`. **Measured this session** (`observations/tag-invalidation-semantics.txt`, `tag-scope-restrictions.txt`, `tag-granularity.txt`): `updateTag` vs `revalidateTag(..., 'max')` on a warm tagged read — not identical; under progressive-enhancement form POST both action responses showed the new price and the SWR stale read appeared on the **next GET**; `updateTag` from a Route Handler and from a Server Component render both fail at **runtime** (different error strings); `revalidateTag` without a profile fails **typecheck** (`TS2554`) but is accepted at runtime with a deprecation warning — **softening the "profile required" claim in articles 6/9 to type-level + warn**; per-slug tags are granular; **inner-tag expiry refreshes an outer composer** (falsifying the draft "stale outer" trap — the trap itself has been removed from Common mistakes, the walkthrough, and the Summary; it survives only as the measurement above). **Corrected in a follow-up pass, same session:** this article's own framing was also wrong. It described `updateTag` vs `revalidateTag` as a writer-visibility choice ("the user who made the change" vs "everyone else"); an instrumented compute counter on `getPlans()` falsified that — both functions render fresh data in the action's own response, and the counter proved that render is a real, uncached computation discarded either way under both functions. The same counter is what settled the propagation measurement above: timing alone couldn't distinguish a stale survivor from a coincidentally-fast recompute. The mechanism section and the walkthrough's decision rule (step 3) are rebuilt on **reader cost**, not writer identity. Every code block is extracted.
