# Cursor — session 15 corrections

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session15-corrections.md
Model:    channel default
Needs:    python3 (rebuilds only; no new experiments)
Commit:   fix: correct articles 9 and 11 from session 15 instrumented measurements
```

The instrumented runs falsified article 11's central framing and turned up a general property of Server Action renders that belongs in article 9. No new measurements — everything below is already captured.

---

## 1. The finding, stated once

Both instrumented runs showed the same thing, and it isn't about tags:

> **A Server Action's re-render does not populate the cache.** Under both `updateTag` and `revalidateTag`, the action's render was a real miss (compute #3), showed fresh data, and was discarded. The next GET never replayed it.

What differs is only the **reader** path:

| | Action render | Next reader |
| --- | --- | --- |
| `updateTag` | fresh, discarded (#3) | **blocking miss** — 187ms, fresh (#4) |
| `revalidateTag(…, 'max')` | fresh, discarded (#3) | **instant hit** — 2ms, pre-write entry (#2); background regen lands as #4 |

Both writers see fresh data. The decision is entirely about the next reader.

## 2. Article 11 — rewrite the mechanism and step 3

**What's wrong now:** the article says the two functions diverge in "the response to the action itself," and step 3 frames the choice as *the user who made the change → `updateTag`, everyone else → `revalidateTag`.* Both are falsified — the writer sees fresh data either way.

**Replace the framing with reader cost:**

> The writer isn't part of this decision. Both functions render fresh data in the action's own response, and neither stores it.
>
> What you're choosing is what happens to **the next person to load the page**: `updateTag` makes them wait for a fresh computation; `revalidateTag` hands them the pre-write value instantly and refreshes behind them.
>
> **`updateTag` buys correctness with latency. `revalidateTag` buys latency with staleness.**

**Rewrite step 3's decision rule** to match — ask what the next reader can afford, not who is looking. Keep the practical shape (a Server Action a user is watching usually still wants `updateTag`), but derive it from reader cost rather than from writer visibility, because the derivation is what makes it transferable.

**Add the symptom to the scenario or Common mistakes** — it's the observable a reader will actually report:

> Under `revalidateTag`, a writer can watch the value go **new → old → new**: the action response shows their edit, the next navigation shows the pre-write value, and a later load shows the edit again. Nothing is broken. They saw a render that was never cached, then rejoined everyone else's timeline.

**Delete the invented trap.** The article warns that invalidating an inner tag may leave an outer scope stale. Measured: inner-tag expiry **did** refresh the outer composer. Remove the Common mistake, remove it from step 5 of the walkthrough, and remove it from the Summary. If `{GRANULARITY_RESULT}` already records the falsification, leave that capture in place — the prose is what needs fixing.

## 3. Article 9 — add the Server Action render property

New subsection under "How it works", after "Composition passes through":

> ### A Server Action's render does not populate the cache
>
> When a Server Action returns and Next.js re-renders the page for that response, cached functions called during that render execute for real — and their results are not stored. The next reader gets a miss, or the pre-existing entry, depending on how the tag was invalidated.
>
> This explains a class of "why is it still recomputing" confusion after a mutation: the work you watched happen was throwaway.

Cite the measurement and cross-link to [`tags-and-invalidation`](./tags-and-invalidation.md) for the two invalidation paths. Add a Summary bullet.

## 4. Articles 6, 9, 11 — soften the profile claim

All three state flatly that `revalidateTag`'s profile argument is **required**. Measured: it's *type*-required (TS2554) and the runtime accepts a single argument with a deprecation warning:

```
"revalidateTag" without the second argument is now deprecated, add second
argument of "max" or use "updateTag".
```

Correct all three to say **type-required, runtime-deprecated**, and add — marked explicitly as **traced to docs and 16.3.0 source, not measured** — that a missing profile behaves as immediate expiry (the same path as `updateTag`), *not* as `'max'`. That distinction matters: someone omitting the argument gets `updateTag` semantics, which is the opposite of what "defaults to stale-while-revalidate" would imply.

Keep the scoping discipline from the session report: measured where measured, traced where traced.

## 5. Verification status footers

Update article 11's and article 9's to record what was falsified and how:

- Article 11: the writer-versus-reader framing was wrong; corrected by an instrumented compute counter across both paths. The inner-tag propagation trap was invented and is falsified.
- Article 9: the Server Action render property was discovered while investigating article 11, not predicted.

Both should note that the compute-counter instrumentation is what settled it — the timing evidence alone was ambiguous.

---

## Acceptance

- [ ] Article 11's mechanism section and step 3 rewritten around reader cost
- [ ] The new → old → new symptom stated where a reader will find it
- [ ] The inner-tag trap removed from Common mistakes, walkthrough step 5, and Summary
- [ ] Article 9 has the Server Action render subsection and a Summary bullet
- [ ] Profile claim corrected in articles 6, 9, and 11, with traced-vs-measured marked
- [ ] Both Verification status footers updated
- [ ] Rebuilt; full gate chain green
- [ ] Report any place the old framing survived that this prompt didn't name
