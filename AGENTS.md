# Agent rules — `nextjs-concepts`

This repo targets **Next.js 16.3.0** (locked in `roadmap.md` §1). Your training
data is older than that and the caching defaults **inverted**.

## Before you write any Next.js code or claim

1. Read `demos/next-lab/node_modules/next/dist/docs/` (resolved from the demo
   package). That tree is the authority. Do not trust training recall.
2. Read `docs/evolution-ledger.md` for the old→new surface map.
3. Hedge explicitly when a claim cannot be verified in-session against those
   sources.

## Banned as live guidance

Never write these as current advice. They appear **only** inside a
**Then vs now** / **How this evolved** / **Migration** section, or inside a
fenced code block whose preceding line carries the legacy marker:

- `export const dynamic`
- `unstable_cache`
- `noStore()` / `unstable_noStore()`
- `experimental_ppr` / `experimental.ppr`
- `fetchCache`
- `middleware.ts` (use `proxy.ts` when teaching the network boundary)

Legacy marker comment, exact form:

```tsx
// legacy: Next <16 implicit-caching model — see docs/evolution-ledger.md
```

## Editorial invariants

- **Then vs now is mandatory** on every concept article (four-column table;
  fourth column = mechanism, not rename).
- Code blocks are extracted verbatim from `demos/next-lab/` — never hand-typed.
- Every claim traces to official docs or framework source before it is written.
