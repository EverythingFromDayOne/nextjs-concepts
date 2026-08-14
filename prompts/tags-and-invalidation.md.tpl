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
verified_on: 2026-08-11
status: draft
---

# Tags and invalidation

> **Lead with this.** A lifetime says how wrong a value may get. A **tag** says who is allowed to make it right again — and Next.js 16 split that into two functions because "make it right" means two different things.
>
> `updateTag` is for the user who just made the change and expects to see it. `revalidateTag` is for everyone else, who would rather have a fast answer than a current one. Choosing wrong produces a bug with no error attached: the write succeeded and the screen didn't move.

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

Both functions expire an entry. What separates them is what the **request that performed the write** sees:

{INVALIDATION_SEMANTICS}

Read the middle column — the response to the action itself. That's where the two diverge, and it's the difference between a user seeing their own edit and a user filing a bug that the save button doesn't work.

The reason this needed two functions rather than one flag: the two behaviours have opposite failure modes. Immediate expiry makes the writer wait for a fresh computation. Stale-while-revalidate makes the writer doubt the write landed. Neither is safe as a default, so Next.js made you pick.

### Where each is allowed

{SCOPE_RESTRICTIONS}

The restriction on `updateTag` follows from what it promises. Read-your-own-writes only means something when there *is* a write and a caller waiting on it — which is the shape of a Server Action and not of a Server Component rendering a page.

### Granularity and propagation

{GRANULARITY_RESULT}

The propagation result is the one to internalise, because a stale outer entry built from freshly-invalidated inner data has no symptom. Nothing errors; the page is just old in one place.

### Tags name entities, not pages

`cacheTag('product:' + slug)` survives a redesign. `cacheTag('product-page')` survives until someone splits the page in two.

The test: **name the write that fires this tag.** If you can describe it — "an admin edits this product" — the tag is at the right granularity. If the answer is "several unrelated things," the tag is too coarse and every one of them will invalidate the others' work.

{EXTRACT:demos/next-lab/lib/catalog.ts#getProduct}

One entry per product, one tag per product, and the write that changes a product expires exactly that entry.

### When a tag is the wrong tool

Not everything has a write you control:

{EXTRACT:demos/next-lab/lib/status.ts}

No tag, deliberately. Nothing in this system can invalidate a third party's status feed, so a tag would be decoration and time is the only honest lever. Worth a comment, so nobody adds one later out of symmetry.

### Long lifetime plus tag beats short lifetime

The pairing that makes caching worth doing. A short lifetime is polling: it guesses at the write, misses it by up to the interval, and — per [`cache-lifetimes`](./cache-lifetimes.md) — may cost you the prerender. A long lifetime with a tag is precise: correct within milliseconds of the write, and prerenderable in between.

If you find yourself shortening a lifetime to make data fresher, the question to ask is what write you're waiting for and whether you can tag it instead.

---

## Basic usage

{EXTRACT:demos/next-lab/lib/billing.ts#getPlans}

Tagged on the read. The write side:

{EXTRACT:demos/next-lab/app/tags/actions.ts}

Both actions do the same write and differ only in how they invalidate. Which one is correct depends entirely on who is looking.

---

## Walkthrough — closing the loop on one mutation

### Step 1 — tag the read

Per entity, named for the thing that changes. `plans` here because a plan edit affects the whole table; `product:${slug}` where one row changes at a time.

### Step 2 — write, then invalidate, in that order

The write has to land before the invalidation, or you expire an entry and immediately rebuild it from the old data. That is a real race and it produces a bug that reproduces about half the time.

### Step 3 — choose the function by who is looking

**The user who made the change** → `updateTag`. They pressed save; they expect to see it.

**Everyone else** → `revalidateTag`. A background sync, a webhook, an admin editing something a thousand people are reading. Nobody is waiting on the specific response, and stale-while-revalidate keeps every one of those thousand reads fast.

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

### Step 5 — check the composition case

If the tagged read is called from *another* cached scope, invalidating the inner tag may leave the outer entry stale — see the propagation result above. Any tag consumed inside another cached scope needs that checked explicitly.

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

**Check tags consumed inside other cached scopes.** Propagation is the trap with no symptom.

---

## API and type reference

| Surface | Import | Notes |
| --- | --- | --- |
| `cacheTag(tag)` | `next/cache` | Inside a cached scope. Multiple tags per scope allowed. |
| `updateTag(tag)` | `next/cache` | Server Actions only — see the measured restriction above. |
| `revalidateTag(tag, profile)` | `next/cache` | Profile argument required. Stale-while-revalidate. |
| `revalidatePath(path)` | `next/cache` | Route-level. Interaction with tagged entries measured above. |

---

## Common mistakes

**1. `revalidateTag` in a Server Action the user is watching.** The write lands, the response shows the old value, the user presses save again. `updateTag` is the fix.

**2. Invalidating before the write completes.** Expire, rebuild from old data, and the new value is gone. Reproduces intermittently, which makes it expensive to find.

**3. Tagging the page.** `cacheTag('dashboard')` invalidates everything or nothing.

**4. Tagging data you can't invalidate.** A tag on a third-party feed is decoration.

**5. Shortening a lifetime instead of adding a tag.** Polling, plus a possible loss of the prerender.

**6. Forgetting propagation.** A tag consumed inside another cached scope may not refresh the outer entry.

**7. Assuming `revalidatePath` covers tagged data.** See the measured result — the route cache it was built for no longer exists in the same form.

**8. Only tagging the reads you remember.** One untagged read of the same data means a page that's fresh in one place and stale in another, with no error.

---

## Exercises

**1. Name the write.** For every `cacheTag` in your app, write the sentence describing the write that fires it. Any tag without a sentence is either miscalibrated or unnecessary.

**2. Reproduce the wrong choice.** Swap `updateTag` for `revalidateTag` in a Server Action and use the form as a user would. The bug you get is the one your users would report as "save doesn't work."

**3. Audit for untagged siblings.** Find data read in more than one cached scope and confirm every one carries the tag. The odd one out is a page that goes stale silently.

---

## Summary

- A lifetime bounds staleness; a **tag** says who can end it early.
- `updateTag` is **read-your-own-writes** and is restricted to Server Actions. `revalidateTag` is **stale-while-revalidate** and requires a profile.
- The difference is observable in the response to the action itself — that's the measurement above, and it's the difference between a user seeing their edit and filing a bug.
- Tags name **entities**, not pages. The test is whether you can name the write.
- **Long lifetime plus a tag** beats a short lifetime: precise instead of polling, and it stays above the prerender thresholds.
- Invalidate **after** the write lands, or you rebuild from stale data.
- A tag consumed inside another cached scope needs its propagation checked.

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

> **Verification status.** Verified against `next@16.3.0`. **This is the least-measured topic in the repository and everything load-bearing here is measured for the first time in this session**: whether `updateTag` and `revalidateTag` actually behave differently in the response to the action that called them — the distinction this entire article is organised around, and one that would collapse if they turned out identical; whether `updateTag` is genuinely restricted to Server Actions and `revalidateTag`'s profile argument genuinely required, both asserted in articles 6 and 9; whether tag invalidation propagates from an inner cached scope to an outer one; and how `revalidatePath` relates to tagged entries now that the Full Route Cache it targeted no longer exists in the same form. Every code block is extracted.
