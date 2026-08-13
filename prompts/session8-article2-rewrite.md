# Cursor — session 8: article 2 rewrite (`foundations/server-and-client-components`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session8-article2-rewrite.md
Model:    channel default
Needs:    pnpm build · pnpm start + curl · python3
```

Article 2 is the last Wave 1 article carrying hand-written code, and three session-7 findings changed its central section. This session **replaces** it — new `.md.tpl`, supersede the drafted `.md`, no patching.

Two experiments. The first tests the article's central claim, which has never been measured.

---

## 0. What changed and why this is a rewrite

Three findings landed after article 2 was drafted:

| Finding | Article 2 currently says | Measured |
| --- | --- | --- |
| Class instance across the boundary | fails **silently** — fields arrive, methods don't | **build failure** on a prerendered route; **runtime-only** if the subtree is postponed |
| Server Component imported into a Client Component | implies a loud failure | **silent** when it has no server-only content — it just becomes a Client Component |
| Enforcement phase | not discussed | depends on whether the containing subtree is prerendered |

The second row is the one that changes the teaching. The article's `import`-vs-`children` section is mechanically correct and gives the wrong impression of the failure mode most readers hit first.

---

## 1. EXPERIMENT A — payload cost across the boundary

**The article's central claim, unverified since it was written:** props are serialized into the RSC payload on *every* render, so passing a large dataset to a Client Component costs bytes per navigation — a cost no bundle report shows.

The stage 1–3 bundle deltas (551 / 452 / 445 B) were too small to carry this. Payload is the right measurement and it has never been taken.

### Setup

Add a scaled generator to `lib/db.ts`:

```ts
export function makeProducts(n: number): Product[] {
  return Array.from({ length: n }, (_, i) => ({
    id: `p${i}`,
    slug: `product-${i}`,
    name: `Product ${i}`,
    description: 'A generated product for payload measurement.',
    priceCents: 1000 + i,
  }))
}
```

Four scratch routes, each rendering **the same visible output** — a list of names — differing only in where the boundary sits:

| Route | Shape |
| --- | --- |
| `payload-a-40` | stage-2: 40 products passed as a prop to a Client Component |
| `payload-a-4000` | stage-2: 4,000 products, same |
| `payload-b-40` | stage-3: 40 rows rendered server-side, passed as `children` through a client shell |
| `payload-b-4000` | stage-3: 4,000 rows, same |

Reuse `FilterShell` / `ProductRow` for the b-shape and `Stage2List` for the a-shape so the comparison is real code, not a contrivance.

### Measure

```bash
pnpm build
pnpm start
curl -s http://localhost:PORT/payload-a-40   | wc -c
# repeat for all four
```

Capture into `observations/payload-boundary.txt`:

- **Total response bytes** for each of the four
- The **build table rows** for all four — bundle size should be near-identical across shapes; that's half the point
- If the RSC payload is separable from the HTML in the response, report both; if not, say so rather than estimating

### What this decides

- **If a-4000 is dramatically larger than b-4000** while bundle sizes match: the claim holds, with numbers.
- **If they're close:** the claim is wrong or the mechanism differs from my description, and the article's central argument needs rewriting. Report that plainly.
- **Also report the 40-product row.** If the difference is negligible at realistic sizes, the honest article says "this matters at thousands, not at dozens" instead of implying it always matters.

Do not tune the routes to make the difference look bigger. If the effect is small, small is the finding.

## 2. EXPERIMENT B — the silent Server Component conversion

Probe 8 established that a Server Component with no server-only content, imported into a Client Component, builds and ships silently. Make the *consequence* visible.

Two scratch routes:

- `convert-a` — `ProductRow` passed as `children` through `FilterShell` (correct composition)
- `convert-b` — `ProductRow` **imported** directly into a client file and rendered there

Same output. Then:

1. Build both. Compare their **First Load JS / bundle rows** — does `ProductRow` and its transitive imports appear in the client bundle for `convert-b`?
2. Add `import 'server-only'` to `product-row.tsx` and rebuild. Does `convert-b` now fail, and at build or runtime?

→ `observations/silent-conversion.txt`

Step 2 is the one worth having. If `server-only` converts a silent failure into a loud one, that is the actionable advice for the article — a one-line guard against the quietest mistake in the model.

## 3. Demo sources to keep

The scratch payload routes get deleted. These stay:

- `lib/db.ts` — the `makeProducts` generator (used by the article)
- `antipatterns/imported-server-component.tsx` — already exists from session 7; verify its `// fails:` line now reads *silently* for the no-server-API case
- `antipatterns/class-instance-prop.tsx` — verify its `// fails:` line reflects the phase-dependence, not a flat "build"

## 4. The rewrite

`prompts/session8/server-and-client-components.md.tpl` ships with this prompt, staged per the convention.

**Final step, after both experiments:** move it to `docs/concepts/foundations/`, **replacing** the existing `.md`, then build and run gates.

It contains two prose placeholders the builder will refuse to fill:

- `{PAYLOAD_TABLE}` — from experiment A
- `{CONVERSION_RESULT}` — from experiment B

Fill both from measurements, not from the surrounding prose.

---

## Acceptance

- [ ] Experiment A: four routes measured, bytes and bundle rows captured; result reported even if it contradicts the claim
- [ ] Experiment B: both steps run; `server-only` outcome recorded with its phase
- [ ] Scratch routes removed; the three kept files verified
- [ ] `{PAYLOAD_TABLE}` and `{CONVERSION_RESULT}` filled from `observations/`, not from prose
- [ ] Old `server-and-client-components.md` replaced, not patched
- [ ] Gates green; report anything that contradicts the delivered template
