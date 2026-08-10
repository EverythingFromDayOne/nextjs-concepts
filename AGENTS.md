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

Never write Ban=`yes` ledger surfaces as current advice. They appear **only**
in one of three allowed forms (enforced by `scripts/verify-legacy-markers.mjs`):

1. Inside a section whose nearest heading matches
   `/then vs now|how this evolved|migration|common mistakes/i`
2. Inside a fenced code block whose **first content line** (or the line
   immediately before the opening fence) carries the legacy marker comment
3. Inside a `legacy-ok` region (for tables / inline prose that must name the
   dead surface outside those sections)

Legacy marker comment, exact form:

```tsx
// legacy: Next <16 implicit-caching model — see docs/evolution-ledger.md
```

Region markers (reason is mandatory and non-empty):

```markdown
<!-- legacy-ok:start reason=historical description of the pre-16 four-layer cache model -->
…content permitted to mention banned surfaces…
<!-- legacy-ok:end -->
```

Missing `reason=`, an unclosed start, or a nested start all fail CI. The
summary line reports how many regions were used; `--verbose` lists each.

Banned examples (see the ledger Ban column for the full list):

- `export const dynamic`
- `unstable_cache`
- `noStore()` / `unstable_noStore()`
- `experimental_ppr` / `experimental.ppr`
- `fetchCache`
- `middleware.ts` (use `proxy.ts` when teaching the network boundary)

## Editorial invariants

- **Then vs now is mandatory** on every concept article (four-column table;
  fourth column = mechanism, not rename).
- Code blocks are extracted verbatim from `demos/next-lab/` — never hand-typed.
- Every claim traces to official docs or framework source before it is written.
