# Cursor — article 5 corrections from session-5 timings

Predictions 1 and 2 confirmed; those sections stand. The **timing** framing in Step 5 does not — the measurement contradicts it, and the corrected version is a better teaching point than the one I wrote.

---

## 1. Step 5 — rewrite the coarse-route paragraph

**Current, wrong:**

> Nothing until the slowest child resolves. One boundary means one arrival, and the arrival is gated by the worst case.

**Replace with:**

> The totals are effectively the same — 1.62s and 1.55s, both gated on the 1.5s errors panel. So is TTFB: 0.08s and 0.03s, single runs and within noise of each other. Both routes flush a shell immediately.
>
> **That is worth sitting with, because it means TTFB cannot tell these two designs apart.** A metric that scores a page with three structured skeletons and a page with one generic block identically is a metric that will never catch a coarse boundary. Neither will total load time, since both finish when the slowest panel does.
>
> What changed is everything between those two numbers. In the fine-grained version revenue is on screen at roughly 200ms and traffic at 600ms. In the coarse version both wait for errors — the same content, seven times later, because they share a boundary with something slow.
>
> The observable signature is in the stream itself: the coarse route swaps its content with a single `$RC` call, the fine-grained one with three. One hole versus three.

The `$RC` detail earns its place — it is the concrete artifact that makes "boundary count" visible rather than conceptual.

## 2. `◐` does not mean the shell is useful

Both routes are annotated `◐` in the build table despite one having a shell worth prefetching and the other having a placeholder. That is a real finding and it belongs in the article.

**Add to "Real-world patterns", after "Verify against the file, never the response":**

> **The build table tells you a shell exists, not that it is worth having.** Both routes in this walkthrough are annotated `◐`. One prerenders a summary and three structured skeletons; the other prerenders a single generic block. The annotation cannot distinguish them, and neither can TTFB. Read the HTML.

**Add to roadmap §5 measurement standard**, alongside the existing `.next/server/app/<route>.html` rule:

> A `◐` annotation reports that a route produced a shell, not that the shell contains anything useful. Shell *quality* claims require reading the artifact.

## 3. Sharpen three places that inherited the wrong framing

- **Mistake #2** — "every panel gated on the slowest" → "every panel's *content* gated on the slowest; the fallback still flushes immediately, which is why this does not show up in TTFB."
- **Summary, bullet 4** — "Shared boundaries are gated on the worst case" → "Shared boundaries make every child's content wait for the slowest, while the fallback flushes at the same speed either way."
- **Exercise 3** — "measure both shells" → "measure both shells *and* time-to-first-panel. Totals and TTFB will not distinguish them."

## 4. Promote to `review`

Both predictions are confirmed and every claim now has an extracted observation behind it. Rewrite the **Verification status** block: prediction 1 and prediction 2 become measured, with the evidence files named; the timing correction above is recorded as a claim that was falsified and rewritten rather than quietly dropped.

Then `status: draft` → `status: review` and confirm `verify-code-blocks --strict` passes.

---

## 5. Workflow locked

15–20 minutes end to end, against 45–60 for the conversion path. `.tpl`-native is the standard for articles 3, 4, 7, 8 and everything after.

Two items of conversion debt remain, tracked by the `unsourced-other` count in the gate summary:

- **Article 1** — convert; the demo routes already exist, so it should be near the cheap end.
- **Article 2** — blocked on its payload measurement (4 products vs 4,000 across the stage-2 boundary). The bundle deltas at 551/452/445 B are too small to carry the claim, and payload is the article's real argument anyway. Measure first, convert second.

That count should fall toward zero and never grow. Growth means a `.tpl`-native article slipped a hand-written fence past the draft exemption.

---

## Acceptance

- [ ] Step 5 paragraph replaced; the TTFB-can't-see-this point is explicit
- [ ] `$RC` signature noted
- [ ] `◐` caveat added to the article and to roadmap §5
- [ ] Three inherited-framing spots sharpened
- [ ] Verification status rewritten, including the falsified-and-rewritten timing claim
- [ ] `status: review`; `--strict` green
