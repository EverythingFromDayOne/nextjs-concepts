# Cursor — session 13: article 9 (`caching/use-cache-directive`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session13-article9-demos.md
Model:    channel default
Needs:    pnpm build (repeatedly) · pnpm start + curl · python3
```

Opens Wave 2 — the caching wave, this repo's differentiator. Six articles; this is the first.

**Three experiments, all testing claims that have been shipped in articles and never measured.** Two of them come from assertions I wrote into demo code in session 3 that then propagated by extraction.

Plus three housekeeping items in §5.

---

## 1. EXPERIMENT A — does argument order change the key?

`lib/catalog.ts` carries this comment, written by me in session 3 and never checked:

> The cache key is derived from the serialized arguments, so `['p1','p2']` and `['p2','p1']` are two different entries for the same result. Sorting before the call is a cache-hit-rate decision, not a style one.

It is extracted into article 1. **If it's wrong, it's been wrong in a shipped article for ten sessions.**

Add an instrumented cached function — a module-level counter incremented on each *miss*, exposed so the route can render it:

```ts
// lib/key-probe.ts
import { cacheLife } from 'next/cache'

let computeCount = 0

export async function probeArray(ids: string[]) {
  'use cache'
  cacheLife('hours')
  computeCount++
  return { ids, computeCount }
}

export async function probeObject(opts: { a: number; b: number }) {
  'use cache'
  cacheLife('hours')
  computeCount++
  return { opts, computeCount }
}
```

Wire a route that calls, in order, and renders each returned `computeCount`:

1. `probeArray(['p1','p2'])`
2. `probeArray(['p1','p2'])` — same order again
3. `probeArray(['p2','p1'])` — reversed
4. `probeObject({ a: 1, b: 2 })`
5. `probeObject({ b: 2, a: 1 })` — same values, different literal key order

→ `observations/key-composition.txt`

**Report the count after each call.** Calls 1 and 2 must share an entry or the probe itself is broken. What calls 3 and 5 do is the finding. If reversed arrays *share* an entry, my comment is wrong — fix the comment in `lib/catalog.ts`, and article 1 corrects on rebuild since it's extracted.

## 2. EXPERIMENT B — is the build ID really in the key?

Articles 1 and 6 both assert that cache entries do not survive a deploy because the build ID is part of every key. **Never measured**, and it's an operational claim teams plan around.

1. `pnpm build && pnpm start`
2. Request the probe route twice — second request should show no new computes (warm).
3. Stop, `pnpm build` again with **no source changes**, `pnpm start`.
4. Request again.

→ `observations/build-id-in-key.txt`

If the count restarts, entries did not survive the rebuild. If it continues, either the build ID isn't in the key or something else persisted — and either way, the claim in two articles needs correcting.

**Note the confound and report on it:** the counter is module state and resets when the process restarts, so a fresh count alone proves nothing. Distinguish "the cache was cold" from "the counter reset" — the artificial DB delay in `lib/db.ts` gives you a timing signal, or add a marker to the cached value that changes only when it's recomputed. Say which method you used.

## 3. EXPERIMENT C — the three directive positions

The article claims `'use cache'` works at file, function, and component level, and that file-level exports can be imported into a Client Component and called directly. Only the function form has ever been exercised in this repo.

Build one of each:

- `lib/cache-file-level.ts` — directive at the top of the file, two exports
- a cached **component** (directive inside an async component function)
- a Client Component that **imports and calls** an export from `cache-file-level.ts`

→ `observations/directive-positions.txt` — does each build, does each work, and does the client-side direct call actually execute on the server (check for a server-side log line, not just a returned value).

**Also check:** at file level, does the directive apply to *every* export, including non-async ones? Probe 1 established non-async cached functions fail — does a file-level directive make a non-async export a build error too?

## 4. Antipatterns to keep (extract-only, tsconfig-excluded)

Reuse existing files where they exist; create only what's missing:

```
antipatterns/non-async-cached-fn.ts          exists (session 7)
antipatterns/missing-cache-life.ts           exists (session 4)
antipatterns/use-cache-on-page.tsx           exists (session 4)
```

Verify each still carries an accurate `// fails:` line against current measurements before extraction.

## 5. Housekeeping — fold in, don't spend a session on it

**Roadmap §7.2 resolved.** The demo lab keeps the in-memory data module for Wave 2. The ORM choice (Drizzle vs Prisma) is deferred to article 44, where it's the subject rather than scenery. Update §1's DB/ORM row and §7.2 to say so — it's decided, not open.

**Article 12 restructured.** Rename `caching/private-and-remote-caches` → `caching/remote-caches-and-durability` in roadmap §3, with `'use cache: private'` demoted to a section rather than a co-headline. Session 11 measured it as providing **zero server-side caching**, so pairing it with `'use cache: remote'` in a title implies a symmetry the measurement contradicts. Update any link or ledger row pointing at the old slug.

**Lint debt recorded.** Add the TS7/eslint mismatch to `progress.md` as open debt, with the actual error text. It's been correctly declared out of scope in three sessions; that should be a tracked decision, not an omission.

## 6. Template

`prompts/session13/use-cache-directive.md.tpl` ships with this. Placeholders:

- `{KEY_COMPOSITION_RESULT}` — experiment A
- `{BUILD_ID_RESULT}` — experiment B, including which method distinguished cold cache from counter reset
- `{DIRECTIVE_POSITIONS_RESULT}` — experiment C

Move to `docs/concepts/caching/` as the final step. Ships `draft`.

---

## Acceptance

- [ ] Experiment A: all five calls' counts reported; `lib/catalog.ts`'s comment confirmed or corrected
- [ ] Experiment B: run, with the counter-reset confound addressed and the method stated
- [ ] Experiment C: all three positions plus the client direct call; file-level + non-async export answered
- [ ] Probe routes removed; the three antipattern files verified accurate
- [ ] All three housekeeping items applied
- [ ] Placeholders filled from `observations/`; gates green
- [ ] **Any experiment result that contradicts articles 1 or 6 named explicitly** — both make claims this session tests
