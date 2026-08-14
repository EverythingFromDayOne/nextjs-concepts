# Cursor — session 15: article 11 (`caching/tags-and-invalidation`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session15-article11-demos.md
Model:    channel default
Needs:    pnpm build · pnpm start + curl · python3
```

Third caching article, and **the least-measured topic in the repository.** Almost nothing here has been exercised: `cacheTag` appears in demo code but has never been invalidated, and neither `updateTag` nor `revalidateTag` has ever been called.

Three experiments. **Experiment A is the reason the article exists** — it measures why two invalidation functions exist rather than one.

This session needs a real mutation, so it adds the first writable data in the demo lab.

---

## 1. A writable store

`lib/db.ts` is read-only. Add a minimal mutable path — no ORM, consistent with the roadmap's decision to defer that to article 44.

```ts
// append to lib/db.ts
const PLAN_PRICES: Record<string, number> = {
  free: 0, pro: 2900, team: 9900,
}

export const mutablePlans = {
  findMany: () => after(180, PLANS.map((p) => ({ ...p, priceCents: PLAN_PRICES[p.id] ?? p.priceCents }))),
  setPrice: async (id: string, cents: number) => {
    await after(50, null)
    PLAN_PRICES[id] = cents
  },
}
```

In-memory and per-process, which is fine — the point is a write that a cached read can observe.

## 2. EXPERIMENT A — why two functions exist

**The core measurement.** `updateTag` is documented for read-your-own-writes; `revalidateTag` for stale-while-revalidate. The observable difference is what the *same request that performed the write* sees afterwards.

Build two Server Actions writing the same data, differing only in which function they call:

```ts
// app/tags/actions.ts
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

Wire both to a route whose plan table is read through a `'use cache'` function tagged `plans`, then submit each form and record **what the response immediately following the action renders**:

- After `setPriceWithUpdate` — the **new** price, or the old one?
- After `setPriceWithRevalidate` — the **old** price, with the new one appearing on a subsequent request?

→ `observations/tag-invalidation-semantics.txt`

Capture the rendered price at three points for each: before the write, in the response to the action, and on the next request after.

**If both behave identically, the distinction I'm about to write an article around doesn't exist in practice**, and that is the finding. Report it plainly rather than assuming the measurement was set up wrong — though do check that the cached read is genuinely warm before the write, since a cold entry would mask the difference.

## 3. EXPERIMENT B — the scope restrictions

Two claims made in articles 6 and 9, never tested:

1. **`updateTag` is Server-Actions-only.** Call it from a Route Handler and from a Server Component. Error, or does it work?
2. **`revalidateTag`'s profile argument is required.** Call `revalidateTag('plans')` with no second argument. Build error, runtime error, or accepted?

→ `observations/tag-scope-restrictions.txt` — exact errors, and their phase (build or runtime), since [`rules-of-the-server-boundary`](../foundations/rules-of-the-server-boundary.md) established that phase depends on route shape here.

## 4. EXPERIMENT C — granularity and propagation

1. **Granularity.** With `product:aeron-chair` and `product:standing-desk` cached separately, invalidate one. Does the other survive? (`lib/catalog.ts#getProduct` already tags per-slug — reuse it.)
2. **Propagation.** An outer cached scope tagged `outer` calling an inner cached scope tagged `inner`. Invalidate `inner` — does the outer entry also refresh, or does it keep serving a result built from stale inner data?
3. **`revalidatePath`.** Call it for a route whose data is tagged. Does it invalidate the tagged entries, or only the route's own rendering?

→ `observations/tag-granularity.txt`

**Item 2 is the one to get right.** If invalidating an inner tag leaves an outer entry stale, that's a composition trap with no obvious symptom, and it belongs in the article's Common mistakes rather than as a footnote.

## 5. Template

`prompts/tags-and-invalidation.md.tpl` ships with this. Placeholders:

- `{INVALIDATION_SEMANTICS}` — experiment A, all six data points
- `{SCOPE_RESTRICTIONS}` — experiment B, both claims with phase
- `{GRANULARITY_RESULT}` — experiment C, all three items

Move to `docs/concepts/caching/` as the final step. Ships `draft`.

---

## Acceptance

- [ ] `mutablePlans` added; the cached read is confirmed warm before each write
- [ ] Experiment A: six data points; identical behaviour reported as such if that's the result
- [ ] Experiment B: both claims, with the error phase noted
- [ ] Experiment C: all three, especially inner-tag propagation
- [ ] Probe routes removed; `app/tags/` retained as the article's demo source
- [ ] Placeholders filled from `observations/`; gates green
- [ ] **Anything contradicting articles 6 or 9 named explicitly**
