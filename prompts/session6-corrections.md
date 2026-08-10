# Cursor — session 6 corrections

Two of these came out of your report rather than the experiments. §1 contradicts a claim I have shipped in two articles and written into the roadmap.

---

## 1. "Insight" is a dev-time presentation, not a severity — and I have this wrong in three places

Your demo note says `/after-demo` failed the build with `blocking-prerender-dynamic` until `connection()` was wrapped in `<Suspense>`.

Session 3's insight probe reported the **same diagnostic** as an insight: HTTP 200, dev-server log, absent from the body — and needed `instant = false` to keep builds green.

Both observations are correct and together they contradict what I wrote in article 4:

> The validator reports two severities: **errors**, which stop a build, and **insights**, which don't. An insight means the route builds and renders but the navigation won't be instant.

That mapping is false. `blocking-prerender-dynamic` is presented as an insight in `next dev`, where the page still serves with a 200 — and is **fatal in `next build`** unless `instant = false` is present.

So the correct statement is stronger and worse: **dev under-reports severity.** A diagnostic that reads as advisory in dev can stop your build.

### Run one clean experiment before rewriting

I do not want to replace one wrong claim with another. Take a bare `connection()` at a page root, no boundary, no `instant = false`, and capture both sides:

```bash
pnpm dev     # capture: HTTP status, response body presence, exact dev-log line
pnpm build   # capture: exact failure output
```

→ `observations/insight-vs-build-error.txt`, both halves in one file with the provenance line.

Also record whether the dev log labels it as an insight, a warning, or something else — my "two severities" framing may have invented a taxonomy that isn't in the output.

### Then fix three places

- **Article 4**, "The insight is not in the response" — rewrite around the dev/build split rather than a severity ladder. The existing point (absent from the HTTP response) stands and is now the *weaker* half of the claim.
- **Article 6**, wherever the same framing appears, plus common mistake #7.
- **Roadmap §5 measurement standard** — currently says insights never appear in the HTTP response. Extend: *and the same diagnostic may be fatal at build, so a passing `next dev` is not evidence of either correctness or buildability.*

## 2. Unify the two sync-IO results into one rule

Experiments 1 and 3 look contradictory and aren't. `new Date()` is fatal in an uncached prerendered scope and **legal, and frozen, inside `'use cache'`**.

The article currently presents these as two facts. They are one:

> **Sync IO is refused where nothing bounds its staleness, and permitted where `cacheLife` does.**
>
> Outside a cached scope, a build-time timestamp is stale relative to nothing — it is frozen for the life of the deployment. Inside one, it is part of a cache entry that expires, so it is exactly as stale as the data it accompanies. That is a structural difference, not a special case.

State the mechanism observationally; the bounded-staleness reading is my inference from the two results, not a documented rationale, and should be marked as such.

Then add the hazard the rule implies, to your new "Cached timestamps are legal — and a trap" section:

> The looser the lifetime, the worse the trap. `cacheLife('minutes')` yields a timestamp that is minutes old and reads as *now*. `cacheLife('max')` yields one that may be weeks old and reads exactly the same. A cached timestamp describes **when the entry was created**, never when it was read — and nothing in the rendered output says which.

Your measurement — identical to the millisecond across two requests 2.5 seconds apart — is the evidence. Make sure the extract shows both timestamps, not one.

## 3. Promote to `review`

After §1 and §2: all four experiments are measured, the falsified severity claim is recorded as falsified-and-rewritten in the Verification status block, and article 4 goes `draft` → `review`.

Note in `progress.md` that the same severity correction was applied to article 6, so it doesn't get rediscovered when article 6 is next touched.

---

## 4. On the timing

80 seconds for a clean observe pass is the number that matters; session 5's 15–20 minutes was mostly authoring and placement. Two things follow:

- **Run the tooling exclusively.** Orphan builds and lock contention inflated your wall time, and that cost recurs every session.
- **The observe pass is no longer the bottleneck**, which means the batching discipline has done its job. Where a future article needs many captures, keep naming every command up front — it is cheap now precisely because it is one pass.

---

## Acceptance

- [ ] `observations/insight-vs-build-error.txt` captures both dev and build halves, plus the actual label used in the dev log
- [ ] Article 4's insight section rewritten around the dev/build split; the response-body point retained as the weaker half
- [ ] Article 6 and roadmap §5 corrected identically; noted in `progress.md`
- [ ] Sync-IO presented as one rule with the inference marked as inference
- [ ] Cached-timestamp trap includes the lifetime-scaling hazard; extract shows both measured timestamps
- [ ] Article 4 at `status: review`; Verification status records the falsified severity claim
