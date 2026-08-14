# Cursor — session 14: article 10 (`caching/cache-lifetimes`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session14-article10-demos.md
Model:    channel default
Needs:    pnpm build · pnpm start + curl with timing · python3 · patience (one experiment waits ~2 min)
```

Second article of the caching wave. Much of it is already measured — the prerender thresholds from session 3, the route-level column rule from session 7. **Three things are not**, and experiment C is the one worth the session.

---

## 1. EXPERIMENT C — separate the `revalidate` and `expire` clocks empirically

*(Listed first because it's the long one; start it and run the others while it waits.)*

Every explanation of these three clocks is a definition. Nobody demonstrates the difference, and the difference is observable with a stopwatch.

The claim under test:

- Between `revalidate` and `expire`: the server serves the **stale** value immediately and regenerates in the background. Request should be **fast**.
- After `expire`: the server must regenerate **synchronously**. Request should be **slow** — roughly the underlying data delay.

`lib/db.ts` already has an artificial 400ms delay. That's the signal.

```ts
// lib/lifetime-probe.ts
import { cacheLife } from 'next/cache'
import { db } from './db'

export async function shortLived() {
  'use cache'
  cacheLife({ stale: 5, revalidate: 10, expire: 60 })
  const plans = await db.plans.findMany()   // ~180ms
  return { plans, generatedAt: new Date().toISOString() }
}
```

Wire it to a route that renders `generatedAt`, then:

```bash
pnpm build && pnpm start
# t=0    first request — cold, slow
# t=15s  past revalidate, before expire — expect FAST + a STALE generatedAt
# t=17s  immediately after — expect the regenerated generatedAt
# t=70s  past expire — expect SLOW + a fresh generatedAt
```

Use `curl -w '%{time_total}'` and record both the timing and the `generatedAt` at each point.

→ `observations/lifetime-clocks.txt`

**Three specific things to report**, because each could come out differently than I expect:

1. Does the t=15s request actually return the *old* `generatedAt`? That's what "stale-while-revalidate" means and it's the observable proof.
2. Does the t=17s request show the regeneration completed in the background?
3. Is the t=70s request measurably slower than t=15s? If both are fast, `expire` doesn't block the way I've described and articles 6 and 9 both need correcting.

If the artificial delay is too small to separate signal from noise, say so and increase it rather than reporting an ambiguous number.

## 2. EXPERIMENT A — nesting propagation

Documented behaviour, asserted in articles 6 and 9, never measured. Two cases:

**A1 — outer with an explicit lifetime.** Outer `cacheLife('days')` calling an inner function with `cacheLife('seconds')`. Does the outer entry get dragged down to the inner's lifetime, or does the explicit outer value win?

**A2 — outer with no `cacheLife`.** Same nesting, but the outer scope omits `cacheLife` entirely. Articles 6 and 9 claim this **throws during prerendering** rather than silently inheriting the shorter lifetime.

→ `observations/lifetime-nesting.txt` — build output for both, exact error text for A2 if it throws.

Also record how the route-level Revalidate/Expire column reports each case. Session 7 established it tracks the shortest *evaluated* entry; this is a second data point for that rule.

## 3. EXPERIMENT B — custom profiles

`cacheLife` accepts named profiles configured in `next.config.ts`, and this repo has never used one.

Add a custom profile, use it in a cached function, and answer:

1. Does it work, and what's the config shape?
2. Does overriding the built-in `default` profile change the behaviour of every scope that omits `cacheLife`?
3. Does `next typegen` produce a type for custom profile names, so a typo is a type error rather than a runtime surprise?

→ `observations/custom-profiles.txt`

Question 3 is the one worth knowing — if profile names are typed, that changes the advice about stringly-typed configuration.

## 4. Reuse, don't recreate

These already exist and article 10 extracts them:

```
observations/alerts-minutes-build.txt     session 3 — in the prerender
observations/alerts-seconds-build.txt     session 3 — out of the prerender
observations/date-in-cache-scope.txt      session 6 — frozen timestamp
antipatterns/missing-cache-life.ts        session 4
lib/status.ts                             the no-tag, time-only case
```

Verify each is present before building; report anything missing rather than recreating it.

## 5. Template

`prompts/session14/cache-lifetimes.md.tpl` ships with this. Placeholders:

- `{CLOCK_SEPARATION}` — experiment C, timings and `generatedAt` values
- `{NESTING_RESULT}` — experiment A, both cases
- `{CUSTOM_PROFILE_RESULT}` — experiment B, all three questions

Move to `docs/concepts/caching/` as the final step. Ships `draft`.

---

## Acceptance

- [ ] Experiment C: all four time points captured with timing **and** `generatedAt`; ambiguity reported rather than smoothed
- [ ] Experiment A: both cases; A2's error text captured if it throws
- [ ] Experiment B: all three questions, including whether profile names are typed
- [ ] Probe routes removed; the five reused artifacts verified present
- [ ] Placeholders filled from `observations/`; gates green
- [ ] **Anything contradicting articles 6 or 9 named explicitly** — both describe these clocks
