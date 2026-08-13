---
article_id: static-shell-and-streaming
concept_folder: rendering
wave: 1
related:
  - foundations/thinking-in-the-app-router
  - caching/cache-components-model
  - routing/instant-navigation-and-prefetching
  - caching/composition-and-cache-boundaries
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-10
status: review
---

# The static shell and streaming

> **Lead with this.** A `<Suspense>` boundary is not a loading spinner. It is the **seam between two rendering passes** — everything above it is computed ahead of the request and written to a file on disk; everything below it is filled in per request and streamed into that file's output.
>
> Which means boundary placement is not a polish decision made at the end. It determines what exists before anyone asks for the page.

---

## What it is

The shell is a real artifact. After `next build`, you can open it: `.next/server/app/streaming.html`.

That file is everything the prerender pass could compute without a request. It is what the first byte of every response to that route is made of, and — since 16.3 extracts shells from any route rather than only from a `loading.tsx` — it is also what a `<Link>` prefetch pulls down before the user clicks.

Three things follow, and they are the whole article:

1. **A boundary decides what is in that file.** Content above a boundary is in the shell; content below it is a hole.
2. **A hole is per-boundary, not per-page.** Sibling boundaries resolve independently, so a slow panel does not delay a fast one.
3. **Cached work needs no boundary.** It resolves during the prerender, so there is nothing to wait for and nothing to stream.

Point 3 is the one people are surprised by. Wrapping cached content in `<Suspense>` is not free insurance — as the walkthrough shows, it can push that content *out* of the shell.

---

## How it works under the hood

### The prerender pass aborts at I/O it cannot reuse

Under Cache Components, the prerender pass renders your tree with no request available. When it reaches data access that is not inside a `'use cache'` scope, it **aborts that subtree** — not because the promise would reject, but because a value computed at build time from an uncached source is a value that will be wrong for somebody.

The abort travels up the tree until it finds a `<Suspense>` boundary. That boundary becomes the hole: the prerender writes its `fallback` into the shell and marks the position for the request pass to fill.

So the rule that determines your shell is not "which components are async." It is: **for each piece of aborting work, which boundary does the abort reach first?**

That framing answers questions that otherwise need memorising:

- *Why did reading `cookies()` at the top of my page cost me the whole shell?* The abort started above every boundary you had.
- *Why does one slow panel block three fast ones?* They share a boundary, so one abort makes one hole containing all four.
- *Why is my cached component missing from the shell?* An aborting sibling turned their shared boundary into a hole, and cached work inside a hole is still inside a hole.

### Boundaries do three jobs, and only one of them is visual

A `<Suspense>` boundary is simultaneously:

1. **A prerender seam.** Above it is shell, below it is hole. This is the job that has no visual component at all and the one most people never think about.
2. **A streaming unit.** At request time, each hole resolves and flushes independently, out of order, as its data arrives.
3. **A fallback owner.** The thing it renders while waiting — which, because of job 1, is also *what gets written into the shell file*.

Job 3 is why fallback design is a performance concern rather than an aesthetic one. The fallback is not shown "while loading" in some ephemeral sense; it is baked into the prerendered HTML and shipped to every visitor. A fallback whose shape does not match what replaces it guarantees a layout shift on every single request.

### `loading.tsx` is a boundary with a fixed position

`loading.tsx` is not a separate mechanism. It is an implicit `<Suspense>` wrapped around the page segment, with your file as the fallback.

That makes it exactly one boundary, at one position: the segment root. Useful, blunt, and — before 16.3 — the *only* prefetchable shell a route could have, which meant forgetting the file silently produced a blocking navigation. Shell extraction from arbitrary trees removed that cliff, and turned `loading.tsx` into what it should always have been: a convenient default for routes whose whole content is one hole, not the mechanism.

### Route shell and App Shell are different things

Two shells appear in 16.3's vocabulary and conflating them will confuse a build output.

- The **route shell** is what we have been describing: this route's prerendered HTML.
- The **App Shell** is the part reusable *across* routes, which is what Partial Prefetching sends once and reuses for many links.

Cache lifetime interacts with the second. Content with a `stale` between 30 seconds and 5 minutes is prerendered into the route shell but excluded from the App Shell — recent enough to prerender, too volatile to hand out as a shared, long-lived prefetch payload. Below 30 seconds, it leaves the prerender entirely, because a prefetch that expires before the click is worse than no prefetch.

---

## Basic usage

Two panels, two speeds, two boundaries:

{EXTRACT:demos/next-lab/app/streaming/page.tsx}

The page component is not `async` and awaits nothing. Its entire job is to declare where the shell ends.

The panels themselves are unremarkable — the boundaries are the design:

{EXTRACT:demos/next-lab/app/streaming/panels.tsx#PanelSkeleton}

---

## Walkthrough — the same page, two boundary placements

Identical data, identical latencies, one difference: three boundaries or one. We will build both and diff their shells.

### Step 1 — the data, deliberately mixed

One cached read and three uncached ones at 200ms, 600ms, and 1500ms. The spread is what makes streaming order observable rather than theoretical.

{EXTRACT:demos/next-lab/lib/report.ts}

`getSummary` is cached and the other three are not. That is not an oversight — it is the setup. Summary is the same for every viewer this hour; the panels are the current state of a live system.

### Step 2 — fine-grained: one boundary per panel

{EXTRACT:demos/next-lab/app/streaming/page.tsx}

Note what is *not* wrapped. `<Summary />` sits outside every boundary because it is cached: it resolves during the prerender, so there is nothing for a boundary to wait on.

### Step 3 — coarse: one boundary around everything

{EXTRACT:demos/next-lab/app/streaming-coarse/page.tsx}

The same four components. The same four awaits. One boundary.

### Step 4 — read the two shells

The shells are files. Open them rather than the browser:

```bash
pnpm build
cat .next/server/app/streaming.html
cat .next/server/app/streaming-coarse.html
```

{EXTRACT:demos/next-lab/observations/streaming-shell-diff.txt}

Two things changed, and only the first is obvious.

**The fine-grained shell carries structure; the coarse one carries a placeholder.** Three skeletons with the right heading and row count versus one generic block. A visitor to the first sees the page's real layout before any request work happens.

**The cached summary left the shell.** This is the one worth internalising. `<Summary />` is cached identically in both files — but in the coarse version it shares a boundary with three aborting siblings, so that boundary became a hole, and everything inside a hole is resolved at request time. Caching bought nothing there. **A badly placed boundary can undo a correct caching decision**, and nothing in the code looks wrong.

### Step 5 — watch them stream

```bash
pnpm start
curl -N --raw -w '\n%{time_starttransfer} first byte\n%{time_total} total\n' http://localhost:3000/streaming
```

{EXTRACT:demos/next-lab/observations/streaming-chunk-order.txt}

Revenue, then traffic, then errors — resolution order, not source order. Each hole flushes as its own data arrives.

Now the same against the coarse route:

{EXTRACT:demos/next-lab/observations/streaming-coarse-timing.txt}

The totals are effectively the same — 1.62s and 1.55s, both gated on the 1.5s errors panel. So is TTFB: 0.08s and 0.03s, single runs and within noise of each other. Both routes flush a shell immediately.

**That is worth sitting with, because it means TTFB cannot tell these two designs apart.** A metric that scores a page with three structured skeletons and a page with one generic block identically is a metric that will never catch a coarse boundary. Neither will total load time, since both finish when the slowest panel does.

What changed is everything between those two numbers. In the fine-grained version revenue is on screen at roughly 200ms and traffic at 600ms. In the coarse version both wait for errors — the same content, seven times later, because they share a boundary with something slow.

The observable signature is in the stream itself: the coarse route swaps its content with a single `$RC` call, the fine-grained one with three. One hole versus three.

### Step 6 — break the fallback on purpose

Swap a matched skeleton for a spinner:

{EXTRACT:demos/next-lab/antipatterns/mismatched-fallback.tsx}

Rebuild, reload with a throttled connection, and watch the layout jump when the table replaces the spinner. The shell reserved the wrong space. Measured as CLS, this is worse than an empty shell — the visitor saw something, believed it, and had it moved.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 8, 9, 20.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Partial Prerendering | `experimental.ppr` plus `experimental_ppr` per segment | Removed — it *is* the rendering model | An opt-in experiment became the architecture, so there is no flag left to enable and no route left that renders the old way. |
| What `<Suspense>` means | A loading state: what to show while a child suspends | Also the **prerender seam** that decides shell membership | The boundary gained a build-time job it did not previously have. The same JSX now determines what exists on disk before any request, not only what the user looks at during one. |
| Prefetchable loading UI | `loading.tsx`, or nothing | A shell extracted from any route's tree | The prefetch payload went from **a file you remembered to write** to **an artifact derived from your boundary placement** — which removes the silent cliff of a missing `loading.tsx` and makes boundary placement a network-performance decision. |
| Cost of a slow data source | De-opted the entire route to request-time rendering | Makes a hole at the nearest boundary; the rest still prerenders | Dynamism moved from a route-level flag consulted by the build planner to **abort propagation from the call site**. Blast radius became a property of your tree rather than of the route. |
| Caching and layout | Independent concerns | Coupled: a boundary containing an aborting sibling pulls cached work into the hole with it | Because cache entries now resolve *during* the prerender rather than filling a route-level cache afterwards, whether they reach the shell depends on whether their enclosing boundary aborts. |

---

## Real-world patterns

**Design the shell first.** Before writing a component, ask what a visitor should see 50ms after clicking with zero data. That answer is your shell, and your boundaries go exactly where that picture ends.

**One boundary per independent wait.** Two panels that fetch from different sources are two boundaries. Sharing one couples their latencies for no benefit and gates both on the worse.

**Don't wrap cached work.** If it resolves during the prerender, a boundary around it can only cost you — and if it shares a boundary with something uncached, it costs you the shell.

**Fallbacks are shells, not spinners.** Match heading, row count, and rough height. A generic spinner in a prerendered shell is a promise the page then breaks.

**Beware the skeleton waterfall.** Nesting a boundary inside a boundary's child means the outer fallback shows, then the inner fallback shows, then content. Three visual states where one would do. Nest only when the inner wait is genuinely independent and slower.

**Layouts are shared shells.** A boundary — or worse, an unbounded runtime read — in a root layout applies to every route beneath it. It is the highest-leverage placement in the app in both directions.

**Verify against the file, never the response.** A streamed response contains the fallback *and* the resolved content, so `curl`, view-source, and DevTools all show a completed stream. `.next/server/app/<route>.html` is the only place the shell exists alone.

**The build table tells you a shell exists, not that it is worth having.** Both routes in this walkthrough are annotated `◐`. One prerenders a summary and three structured skeletons; the other prerenders a single generic block. The annotation cannot distinguish them, and neither can TTFB. Read the HTML.

---

## API and type reference

| Surface | Where | Role |
| --- | --- | --- |
| `<Suspense fallback>` | `react` | Prerender seam, streaming unit, and fallback owner. |
| `loading.tsx` | route segment | An implicit `<Suspense>` at the segment root. One boundary, fixed position. |
| `'use cache'` | directive | Resolves during the prerender; needs no boundary. |
| `connection()` | `next/server` | Forces an abort at its call site. The explicit form of what `cookies()` does implicitly. |
| `export const instant = false` | segment config | Permits a segment to block, and silences the validator's insight about it. Temporary by intent. |
| `.next/server/app/<route>.html` | build output | The shell, in isolation. The only honest place to verify shell claims. |
| `partialPrefetching` | `next.config.ts` | Extracts reusable shells across routes for prefetching. |

---

## Common mistakes

**1. Treating `<Suspense>` as decoration.** It is the seam that decides what exists on disk. Adding one changes your build output, not just your loading state.

**2. One boundary around the whole page.** Correct, and it throws away everything the model offers: no structural shell, and every panel's *content* gated on the slowest; the fallback still flushes immediately, which is why this does not show up in TTFB.

**3. Wrapping cached content alongside uncached content.** The boundary becomes a hole and the cached work goes into it. Your caching still works; it just no longer reaches the shell.

**4. A fallback that doesn't match its content.** The fallback is prerendered HTML shipped to everyone. A mismatched one guarantees a layout shift on every request.

**5. Assuming `loading.tsx` is the only way to get a loading state.** It is one boundary at the segment root. Since 16.3, shells are extracted from any tree, so explicit boundaries are usually the better tool.

**6. Nesting boundaries for tidiness.** Each nesting level is another visual state the user watches. Nest for independent waits, not for code structure.

**7. Verifying the shell in the browser.** View-source shows a completed stream. Read the build artifact.

**8. Reaching for `instant = false` to make the warning go away.** It permits blocking and silences the insight — which is its purpose, and exactly why leaving it in place converts a temporary acknowledgement into a permanent regression.

---

## Exercises

**1. Predict, then read.** Before running anything, write down which elements you expect in `/streaming`'s shell and which in `/streaming-coarse`'s. Then `cat` both files.

*Hint: the disagreement most people have with themselves is about `<Summary />`.*

**2. Move one boundary.** In `/streaming`, wrap `<Summary />` in its own `<Suspense>`. Rebuild and diff the shell against the original.

*Hint: it is cached, so nothing aborts inside the new boundary. Does the boundary change anything at all? Explain the result either way.*

**3. Find the coupled pair.** In an app you already have, find two pieces of data sharing a boundary that have no reason to. Split them and measure both shells *and* time-to-first-panel. Totals and TTFB will not distinguish them.

*Hint: the usual culprit is a `loading.tsx` doing work that two explicit boundaries would do better.*

---

## Summary

- The shell is a file: `.next/server/app/<route>.html`. It is the first byte of every response and the payload of every prefetch.
- The prerender pass **aborts** at uncached I/O; the abort rises to the nearest `<Suspense>`, and that boundary becomes a hole.
- A boundary does three jobs — prerender seam, streaming unit, fallback owner — and only the last is visual.
- Sibling boundaries resolve independently and out of order. Shared boundaries make every child's content wait for the slowest, while the fallback flushes at the same speed either way.
- Cached work resolves during the prerender and needs no boundary. Putting one around it, next to something uncached, removes it from the shell.
- `loading.tsx` is one implicit boundary at the segment root, not a separate mechanism.
- Fallbacks are prerendered HTML. A mismatched one is a guaranteed layout shift, not a cosmetic detail.

---

## See also

- [`foundations/thinking-in-the-app-router`](../foundations/thinking-in-the-app-router.md) — the four answers this article's boundaries implement
- [`caching/cache-components-model`](../caching/cache-components-model.md) — why uncached I/O aborts in the first place
- [`caching/composition-and-cache-boundaries`](../caching/composition-and-cache-boundaries.md) — the same placement question from the caching side
- [`routing/instant-navigation-and-prefetching`](../routing/instant-navigation-and-prefetching.md) — what the shell is used for once it exists
- [`caching/cache-lifetimes`](../caching/cache-lifetimes.md) — the thresholds that keep content out of the shell and the App Shell
- [`reactjs-concepts` → `rendering/suspense`](../../../../reactjs-concepts/docs/concepts/rendering/suspense.md) — Suspense as a React primitive, without the build-time job

---

## References

- Next.js — Getting Started: Partial Prerendering
- Next.js — Guides: Instant Navigation
- Next.js — `next.config.js: cacheComponents`, `partialPrefetching`
- Next.js — File conventions: `loading.tsx`
- Next.js — Functions: `connection`, `cacheLife`
- Next.js blog — Next.js 16.3 (2026-08-03)
- React — `<Suspense>`

---

## Demo source

`demos/next-lab/app/streaming/`, `demos/next-lab/app/streaming-coarse/`, `demos/next-lab/lib/report.ts`, `demos/next-lab/antipatterns/mismatched-fallback.tsx`, and the six capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0` (docs + demo). **Measured:** prediction 1 — fine shell has summary + three matched skeletons (`observations/streaming-fine-shell.html.txt`); coarse shell has only the one skeleton (`streaming-coarse-shell.html.txt`, `streaming-shell-diff.txt`). Prediction 2 — cached `<Summary />` absent from the coarse prerender (no `2026-W32` / summary header in that artifact). Both routes annotated `◐` (`streaming-build-table.txt`) — annotation reports a shell exists, not that it is useful. Timings (`streaming-chunk-order.txt`, `streaming-coarse-timing.txt`): fine TTFB≈0.08s / total≈1.62s; coarse TTFB≈0.03s / total≈1.55s; both gated on the 1.5s errors panel. **Falsified and rewritten:** the draft claim that coarse means "nothing until the slowest child resolves" — both routes flush a shell immediately; what differs is content between TTFB and total (one `$RC` vs three). Traced: shell-as-file method, abort propagation, App Shell `stale` thresholds. Every code block and observation is extracted.
