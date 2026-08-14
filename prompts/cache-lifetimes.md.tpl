---
article_id: cache-lifetimes
concept_folder: caching
wave: 2
related:
  - caching/use-cache-directive
  - caching/cache-components-model
  - caching/tags-and-invalidation
  - rendering/static-shell-and-streaming
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-11
status: draft
---

# Cache lifetimes

> **Lead with this.** `cacheLife` is not a TTL. It is **three independent clocks**, and the shortest of them decides something most people don't expect: not just how fresh the value is, but **whether the content can be prerendered at all**.
>
> Set a lifetime short enough and you didn't cache it briefly — you converted it into a streamed hole with a server-side cache in front. The answer you picked was "cache it"; the answer the framework acted on was "stream it."

---

## What it is

Three clocks, measured from when the entry was created:

| Clock | Who it governs | What happens when it passes |
| --- | --- | --- |
| **`stale`** | The **client** router | The browser stops reusing its copy and asks the server |
| **`revalidate`** | The **server**, in the background | The old value is still served; a fresh one is computed behind it |
| **`expire`** | The **server**, synchronously | The next request must wait for a fresh value |

The default profile is `stale` 5 minutes, `revalidate` 15 minutes, `expire` never.

They are not three names for one number. Between `revalidate` and `expire` you are deliberately serving something you know is out of date, because the alternative is making someone wait for it.

---

## How it works under the hood

### The middle clock, measured

The distinction between `revalidate` and `expire` is usually explained and rarely shown. With a known delay behind the cached call, it's observable:

{CLOCK_SEPARATION}

The `generatedAt` values are the proof, not the timings. A fast response carrying an *old* timestamp is stale-while-revalidate doing exactly what it says; a slow response carrying a fresh one is the synchronous path after `expire`.

That gap between the two clocks is the whole product decision. Widen it and users get fast responses that are sometimes wrong. Narrow it and they get correct responses that sometimes block. Setting them equal removes the mechanism entirely.

### Lifetime decides *placement*, not just freshness

The part that surprises people. A short enough lifetime disqualifies content from the prerender:

| Condition | Effect |
| --- | --- |
| `revalidate: 0`, or `expire` under 5 minutes | Excluded from prerenders — becomes a dynamic hole resolved at request time |
| `stale` under 30 seconds | Excluded from prerenders, because a prefetch would expire before the user could click |
| `stale` between 30 seconds and 5 minutes | Prerendered, but excluded from the route's App Shell |

Of the built-in profiles, only `seconds` crosses any threshold — its one-minute `expire` keeps it out of prerenders.

Measured, with only one function's `cacheLife` changed between builds:

{EXTRACT:demos/next-lab/observations/alerts-minutes-build.txt}

{EXTRACT:demos/next-lab/observations/alerts-seconds-build.txt}

Same code, same data, same tag. One value in one call changed whether the content exists in `.next/server/app/dashboard.html`.

This is not a gotcha. It's the framework refusing to prerender something that would be stale before anyone saw it. But it explains build output that otherwise looks wrong, and it means **`cacheLife` is a rendering decision as much as a freshness one.**

### Nesting, and the error that exists to stop a silent surprise

{NESTING_RESULT}

The reason this is an error rather than a silent inheritance: the inner cache can easily be somewhere you aren't looking — an imported module, a transitive dependency. A scope whose lifetime is quietly determined by a callee you've never opened is a scope you can't reason about.

Which is why the convention is *call `cacheLife` in every cached scope*:

{EXTRACT:demos/next-lab/antipatterns/missing-cache-life.ts}

Not ceremony. It's what makes a cached function's lifetime readable without tracing its callees.

### Built-in and custom profiles

{CUSTOM_PROFILE_RESULT}

The built-ins exist so the common cases don't require you to reason about three numbers. Reach for a custom profile when you have a real reason the built-ins don't cover — and name it after the *data*, not the duration, so it survives a change of mind about the numbers.

### What the route-level column reports

`next build` prints a Revalidate and Expire column per route. It tracks the **shortest evaluated entry** on that route.

Two consequences worth internalising before you read it as "the lifetime of this page":

- A route holding entries at `days` and `minutes` reports `minutes`. There is no single lifetime; the column picks one.
- **Evaluated and prerendered are different sets.** A route can report a lifetime for an entry that isn't in its shell at all — which is exactly what a coarse `<Suspense>` boundary produces.

It's a leftover of route-level thinking surviving in the output format. Useful as a smell test; misleading as an answer.

### Lifetime is a ceiling, not a promise

`cacheLife('days')` does not mean the value is a day old. It means it *may* be. A tag invalidation expires the entry immediately regardless, and a deploy invalidates everything because the build ID is part of every key.

So the honest reading of a lifetime is **"how wrong is this allowed to get if nothing invalidates it"** — a bound on the worst case, not a description of the normal one.

---

## Basic usage

{EXTRACT:demos/next-lab/lib/status.ts}

A third-party feed with no write we control. No tag, deliberately — time is the only honest lever, and `cacheLife('minutes')` keeps it in the prerender where `'seconds'` would not.

---

## Walkthrough — choosing a lifetime on purpose

### Step 1 — ask how wrong it's allowed to be

Not "how often does it change." Those are different questions, and the second one leads people to set a lifetime matching their write frequency, which is what tags are for.

A pricing table changes monthly and must be correct within seconds of a change → the *lifetime* can be long, because the **tag** does the work.

### Step 2 — decide whether you have a write to hook

If a write in your system changes the value, tag it and let the lifetime be generous. If nothing you control changes it, time is your only lever and the lifetime is doing real work:

{EXTRACT:demos/next-lab/lib/status.ts}

### Step 3 — check the placement thresholds

Before settling on a number, check it against the table above. If your lifetime crosses a threshold, you have chosen "stream it" — which may be correct, but should be deliberate.

### Step 4 — set the gap between `revalidate` and `expire`

`revalidate` is when you're willing to serve something known-stale. `expire` is the point past which you'd rather someone waited. Equal values remove the background-refresh mechanism entirely.

### Step 5 — declare it explicitly, always

{EXTRACT:demos/next-lab/lib/billing.ts#getUsage}

Even when it matches the default. It's what stops a callee from deciding for you.

### Step 6 — verify

```bash
pnpm build
```

1. Read the route's Revalidate/Expire column — and remember it reports the shortest *evaluated* entry, not the page's lifetime.
2. Read `.next/server/app/<route>.html` and confirm the content is where you expect. If you crossed a threshold, it won't be in the shell.
3. Halve the lifetime, rebuild, and diff the shell. That round trip is the placement mechanism observed rather than believed.
4. For the clock behaviour, reproduce the timing measurement above against your own data delay.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 3, 5.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Where lifetime is declared | `export const revalidate = 3600` on the route segment | `cacheLife(profile)` inside the cached scope | A **whole-route declaration resolved at build planning** became a **profile attached to one entry**. One route can now hold many entries with different lifetimes, which a segment config could not express. |
| How many numbers | One — `revalidate` | Three — `stale`, `revalidate`, `expire` | Client reuse, background refresh, and forced synchronous regeneration were one setting and are now three, because they govern three different actors. |
| Effect on rendering | None — the route's static/dynamic classification was decided separately | Lifetime **determines prerender eligibility** | Because cache entries now resolve *during* the prerender rather than filling a route-level cache afterwards, a value too short-lived to be worth prerendering is excluded from it. |
| Nesting | Not applicable — one value per route | An inner scope can affect an outer one, or throw | Per-scope lifetimes made composition possible and therefore made lifetime propagation a thing that needed rules. |
| `fetch`-level revalidation | `fetch(url, { next: { revalidate } })` | Wrap the fetch in a cached scope with `cacheLife` | Lifetime stopped being a property of `fetch` specifically and became a property of any cached work. |

---

## Real-world patterns

**Ask "how wrong may this get," not "how often does it change."** Change frequency is what tags handle.

**Long lifetimes plus tags beat short lifetimes.** A tag invalidates precisely on the write; a short lifetime guesses, misses, and costs you the prerender besides.

**Time is only the right lever when you own no write.** Third-party feeds, aggregate counts, anything upstream. Say so in a comment so nobody adds a decorative tag later.

**Check the thresholds before committing to a number.** The difference between `minutes` and `seconds` is not four orders of magnitude of freshness — it's whether the content is in your shell.

**Declare a lifetime in every scope**, even when it matches the default.

**Name custom profiles after the data.** `catalog` and `livePricing` survive a change of mind about the numbers; `fiveMinutes` doesn't.

**Read the build column as a smell test.** Shortest evaluated entry, and evaluated isn't the same as prerendered.

---

## API and type reference

| Surface | Form | Notes |
| --- | --- | --- |
| `cacheLife('hours')` | built-in profile name | Cannot be called at module scope. |
| `cacheLife({ stale, revalidate, expire })` | inline object | Seconds. Any clock may be omitted. |
| `cacheLife('myProfile')` | custom profile | Defined in `next.config.ts` — see the measured result above for typing. |
| `stale` | seconds | Client router reuse window. Under 30s excludes content from prerenders. |
| `revalidate` | seconds | Background refresh point. `0` excludes from prerenders. |
| `expire` | seconds | Forced synchronous regeneration. Under 5 minutes excludes from prerenders. |

---

## Common mistakes

**1. Treating `cacheLife` as a TTL.** Three clocks governing three actors.

**2. Setting `revalidate` and `expire` equal.** Removes stale-while-revalidate entirely — every request past the point blocks.

**3. Expecting `cacheLife('seconds')` to be prerendered.** Its one-minute `expire` disqualifies it. You asked to cache it; you got a streamed hole with a server cache in front.

**4. Matching the lifetime to the write frequency.** That's the tag's job. Long lifetime plus a tag is almost always better.

**5. Omitting `cacheLife`.** Either you inherit the default, or a callee drags you down, or it throws — see the measured nesting result.

**6. Reading the route column as the page's lifetime.** Shortest evaluated entry, and evaluated ≠ prerendered.

**7. Reading a lifetime as a description rather than a bound.** It's how wrong the value may get, not how old it is.

**8. Naming custom profiles after durations.** `fiveMinutes` is wrong the moment you change it to six.

---

## Exercises

**1. Find a lifetime doing the tag's job.** Look for a cached scope with a short lifetime and no `cacheTag`. If a write in your system changes that data, you're paying for polling.

**2. Cross a threshold on purpose.** Take a cached value currently in your shell, drop its lifetime below the threshold, rebuild, and diff `.next/server/app/<route>.html`.

**3. Observe the middle clock.** Reproduce the timing measurement above against your own data. If you can't tell the two responses apart, your underlying call is too fast for the distinction to matter — which is itself a useful thing to know about that value.

---

## Summary

- `cacheLife` is **three clocks**: `stale` (client reuse), `revalidate` (background refresh), `expire` (forced synchronous).
- The gap between `revalidate` and `expire` is where stale-while-revalidate lives. Equal values remove it.
- **Lifetime decides placement.** Cross a threshold and the content leaves the prerender — you chose "stream it" without meaning to.
- Nesting propagates: an inner scope can affect an outer one, and an outer scope with no explicit lifetime throws rather than silently inheriting.
- A lifetime is a **ceiling**, not a description. Tags and deploys invalidate regardless.
- The route-level build column reports the **shortest evaluated entry** — and evaluated is not the same set as prerendered.

---

## See also

- [`caching/use-cache-directive`](./use-cache-directive.md) — what enters the key that a lifetime attaches to
- [`caching/tags-and-invalidation`](./tags-and-invalidation.md) — the lever that makes long lifetimes safe
- [`caching/cache-components-model`](./cache-components-model.md) — why lifetime interacts with rendering at all
- [`rendering/static-shell-and-streaming`](../rendering/static-shell-and-streaming.md) — the prerender the thresholds exclude you from
- [`caching/remote-caches-and-durability`](./remote-caches-and-durability.md) — lifetimes when storage survives a deploy

---

## References

- Next.js — Functions: `cacheLife`, `cacheTag`
- Next.js — `next.config.js: cacheLife`, `cacheComponents`
- Next.js — Getting Started: Caching
- Next.js — Guides: Instant Navigation

---

## Demo source

`demos/next-lab/lib/status.ts`, `lib/billing.ts`, `lib/lifetime-probe.ts`, `demos/next-lab/antipatterns/missing-cache-life.ts`, and the capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0`. The prerender thresholds and the placement effect were measured in session 3; the route-level column rule in session 7. **Three items are measured for the first time here**: the empirical separation of `revalidate` and `expire` — usually only defined, never demonstrated — including whether the mid-window response really carries a stale value; nesting propagation in both the explicit-outer and omitted-outer cases, the latter of which articles 6 and 9 claim throws during prerendering; and whether custom profile names are typed by `next typegen`. Any of these coming back differently corrects an earlier article. Every code block is extracted.
