---
recipe_id: everything-went-dynamic-after-the-upgrade
primary_concept: caching/cache-components-model
difficulty: foundational
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-11
status: draft
---

# Everything went dynamic after the upgrade

> **Symptom.** You upgraded to Next.js 16 and turned on Cache Components. Pages that were static now render on every request. TTFB is up, your infrastructure bill is up, and the build output that used to be full of `○` is now full of `ƒ`. Nothing is broken, exactly. Everything is just slower.

---

## What you'll build

The migration, staged the way it actually happens: build, read the error, fix that one thing, build again. Plus the measurement that tells you when you're done — because "it builds" and "it's fast again" are separated by the entire second half of this recipe.

---

## The scenario

An app that worked on Next 15. Segment configs, `unstable_cache`, `fetch` with `next: { revalidate }`, a dashboard reading cookies at the page root. All of it correct in 15.

You set `cacheComponents: true`, and the build stops.

You fix what it names. It stops again, somewhere else. You fix that. Eventually it builds — **and now the page is dynamic, which is worse than where you started.**

That last step is the one nobody warns about, and it's why this recipe has two halves.

### Why it happens

Next 16 inverted the default. Before, the framework cached aggressively and you opted out; now nothing is cached unless you opt in with `'use cache'`.

So the segment configs you deleted weren't providing caching — they were *describing* a default that no longer exists. Delete them and you don't lose caching; you discover you never declared any. The implicit caching that made your app fast was doing work nobody had chosen, and the upgrade makes that choice explicit by taking it away first.

---

## Why it escaped QA

**It isn't a bug.** Every page renders correctly. Tests pass, screenshots match, nothing errors. The only symptom is cost and latency, and neither shows up in a test suite.

**The build tells you when you're broken, not when you're slow.** Once the errors clear, the build is green — with every route dynamic. Green is not the finish line here, and it feels like one.

**Dev doesn't reproduce it.** Prefetching is off and cache behaviour differs, so the thing you're trying to fix isn't observable where you're working.

---

## Walkthrough

### Step 1 — the code, unchanged

The before-state, correct on Next 15 and untouched:

{EXTRACT:demos/next-lab/legacy/dashboard-page.next15.tsx}

### Step 2 — turn it on and read the cascade

{ERROR_CASCADE}

Two things to take from that sequence.

**Fix exactly what the error names, then rebuild.** Trying to fix everything at once means you can't tell which change addressed which error, and several of these interact.

**Watch the build row move.** The route's progression through the build table is the real progress indicator — more honest than the error count, because it shows you the state you're actually in rather than the errors you've cleared.

### Step 3 — the state nobody warns you about

You've cleared every error. The build is green. Now measure it:

{BEFORE_AFTER}

The intermediate row is the point of this recipe. **The route builds, and it is worse than before the upgrade** — everything dynamic, nothing prerendered, no shell. You haven't broken anything; you've removed implicit caching and not yet replaced it with explicit caching.

This is the honest halfway state, and mistaking it for the destination is the commonest way people conclude the upgrade made their app slow.

### Step 4 — decide, per read, what it should be

The actual work. For each piece of data, one of four answers, and a table you fill before writing code:

| Read | Same for everyone? | Invalidating write? | Answer |
| --- | --- | --- | --- |
| Plans | Yes | Admin edits pricing | Cache it, tag `plans` |
| Usage | No — per user | — | Stream it, identity read outside |
| Status feed | Yes | None we control | Cache it, short lifetime, no tag |
| Timestamp | No — per request | — | Stream it, after `connection()` |

If you can't name the invalidating write, the answer is "stream it," not "cache it." Most of the migration is filling in this table honestly; the code is transcription.

### Step 5 — cache the access, not the route

{EXTRACT:demos/next-lab/lib/billing.ts#getPlans}

At the function that touches the data source. Not the page — a directive at the page root produces one coarse entry keyed by almost nothing and forbids every runtime read below it.

### Step 6 — move runtime reads below boundaries

{EXTRACT:demos/next-lab/app/dashboard/page.tsx}

The page component isn't `async` and awaits nothing. Its job is to declare where the shell ends. A `cookies()` read at the top would put the abort above every boundary and cost you the shell entirely.

### Step 7 — measure, don't assume

```bash
pnpm build && pnpm start
```

1. Build table: is the route `◐` rather than `ƒ`?
2. `.next/server/app/<route>.html` — is the prerendered content actually there? **Read the file, not the response** — a streamed response contains both the fallback and the resolved content.
3. Compare against the intermediate state you captured in step 3. That delta is what the work bought.

---

## Variations

**One route at a time.** `instant = false` parks a route so the rest can migrate. It's a marker, not a fix — see below.

**A shared layout reading cookies.** Highest-leverage single fix in most apps: one runtime read there costs the shell for every route beneath it. Check layouts before pages.

**`unstable_cache` with manual keys.** The key array becomes the function's arguments. Anything the old key array contained that isn't an argument now has to become one.

**Third-party data with no write you control.** Time is the only lever; skip the tag and say why in a comment.

---

## What doesn't work

{DOESNT_WORK}

{CODEMOD_RESULT}

---

## Trade-offs and pitfalls

**1. Green is not the finish line.** The build passes with every route dynamic. That state is worse than pre-upgrade.

**2. Don't fix errors in batches.** Several interact; fixing them together hides which change did what.

**3. `next dev` won't show you the problem.** Prefetching off, cache behaviour different. Measure with `next build && next start`.

**4. Don't reach for `'use cache'` at the page root.** One coarse entry, and no runtime reads permitted below it.

**5. Cache entries don't survive a deploy.** Build-ID-keyed and in-memory by default. If you're coming from `unstable_cache` or the Data Cache, both of which persisted, expect a cold-start cost after every release.

**6. `instant = false` is not free.** It permits blocking and silences the diagnostic — and the segment loses its shell. It's a marker for "not migrated yet," not a resting state.

**7. Deleting a segment config doesn't remove caching.** It removes a description of a default that's already gone.

**8. Shortening lifetimes to compensate.** A lifetime short enough to feel fresh may fall below the prerender thresholds and drop the content out of your shell entirely.

**9. Migrating leaf pages first.** Layouts have the blast radius. Start there.

**10. Assuming the four-answer table is quick.** It's the actual work. The code is the easy part.

**11. Treating a passing dev server as evidence.** The same diagnostic can be advisory in dev and fatal at build.

### When NOT to use this approach

If the app is small and mostly static, the staged migration is overhead. Turn on Cache Components, add `'use cache'` to the handful of data functions, and check the build table — the incremental machinery exists for codebases where you can't hold the whole thing in your head at once.

And if you're not ready to do the per-read classification at all, **don't half-migrate.** An app where every route carries `instant = false` builds, ships, and has quietly given up prerendering everywhere. Staying on 15 until you have time to do it properly is a legitimate choice; a permanently parked migration is not.

---

## Verify the loop

1. Every route `◐` or `○` rather than `ƒ` — or `ƒ` for a documented reason.
2. `.next/server/app/<route>.html` contains what you expect for each migrated route.
3. No `instant = false` left except where you can name why.
4. Every `'use cache'` has a `cacheLife`, and a `cacheTag` unless you own no write.
5. Every runtime read sits below a boundary, or in a component that has one above it.
6. Layouts audited before pages.
7. Measured with a production build, never dev.

---

## See also

- [`caching/cache-components-model`](../../concepts/caching/cache-components-model.md) — the inversion and the four answers
- [`caching/use-cache-directive`](../../concepts/caching/use-cache-directive.md) — where the directive goes
- [`caching/cache-lifetimes`](../../concepts/caching/cache-lifetimes.md) — why a short lifetime can cost you the shell
- [`foundations/thinking-in-the-app-router`](../../concepts/foundations/thinking-in-the-app-router.md) — shell and holes
- [`rendering/static-shell-and-streaming`](../../concepts/rendering/static-shell-and-streaming.md) — measuring the shell properly
- [`migration/adopting-cache-components`](../../concepts/migration/adopting-cache-components.md) — the same work at repository scale

---

## References

- Next.js — Guides: Migrating to Cache Components
- Next.js — `next.config.js: cacheComponents`
- Next.js — Directives: `use cache`
- Next.js — Functions: `cacheLife`, `cacheTag`, `connection`

---

## Demo source

`demos/next-lab/legacy/dashboard-page.next15.tsx`, `demos/next-lab/app/upgrade-lab/`, `demos/next-lab/app/dashboard/`, `demos/next-lab/lib/billing.ts`, `lib/status.ts`, and the capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0`. The error cascade is captured **in the order it actually surfaces** by compiling unmodified Next 15 code with Cache Components enabled and fixing one error at a time — not reconstructed from documentation, and not from my prediction of the order. The intermediate all-dynamic state is measured deliberately, because the claim that it is *worse than pre-upgrade* is the recipe's central warning and would be worth nothing asserted. Both `What doesn't work` candidates were tested rather than assumed, including whether a permanent `instant = false` is a viable resting state. Every code block and capture is extracted.
