# Progress

Living status board. Plan lives in `roadmap.md` (revision 2 — **47 articles**).
Numbering = reading order. No revision-1 (42-article) numbering survives here.

## Legend

| Mark | Meaning |
| --- | --- |
| ✅ | Landed and gates green |
| 🟢 | Draft complete, awaiting review |
| 🟡 | In progress |
| ⚪ | Not started |
| ❌ | Blocked / failed verification |

---

## Wave 1 — The model (8)

| # | Slug | Status | Notes |
| --- | --- | --- | --- |
| 1 | `foundations/thinking-in-the-app-router` | 🟢 | Draft on disk; authored blocks; see demo backlog |
| 2 | `foundations/server-and-client-components` | 🟢 | Draft on disk; authored blocks; see demo backlog |
| 3 | `foundations/file-conventions-and-the-route-tree` | ⚪ | |
| 4 | `foundations/build-time-request-time-and-the-client` | 🟢 | `status: review`; Exp1–4 measured; severity claim falsified+rewritten; sync-IO one-rule |
| 5 | `rendering/static-shell-and-streaming` | 🟢 | `status: review`; predictions measured; TTFB framing corrected |
| 6 | `caching/cache-components-model` | 🟢 | `status: review`; `.md.tpl` extraction pipeline proven |
| 7 | `rendering/client-side-rendering` | ⚪ | |
| 8 | `foundations/rules-of-the-server-boundary` | ⚪ | |

## Wave 2 — Caching (6)

| # | Slug | Status | Notes |
| --- | --- | --- | --- |
| 9 | `caching/use-cache-directive` | ⚪ | |
| 10 | `caching/cache-lifetimes` | ⚪ | |
| 11 | `caching/tags-and-invalidation` | ⚪ | |
| 12 | `caching/private-and-remote-caches` | ⚪ | |
| 13 | `caching/composition-and-cache-boundaries` | ⚪ | |
| 14 | `caching/the-other-cache-layers` | ⚪ | |

## Wave 3 — Data and mutations (8)

| # | Slug | Status | Notes |
| --- | --- | --- | --- |
| 15 | `data/fetching-on-the-server` | ⚪ | |
| 16 | `data/runtime-data-and-cached-scopes` | ⚪ | |
| 17 | `data/route-handlers` | ⚪ | |
| 18 | `mutations/server-functions` | ⚪ | |
| 19 | `mutations/forms-and-action-state` | ⚪ | |
| 20 | `mutations/validation-and-error-surfaces` | ⚪ | |
| 21 | `mutations/closing-the-loop` | ⚪ | |
| 22 | `mutations/server-function-security` | ⚪ | |

## Wave 4 — Routing and navigation (8)

| # | Slug | Status | Notes |
| --- | --- | --- | --- |
| 23 | `routing/route-groups-and-project-structure` | ⚪ | |
| 24 | `routing/layouts-templates-and-state` | ⚪ | |
| 25 | `routing/dynamic-routes-and-params` | ⚪ | |
| 26 | `routing/root-params` | ⚪ | |
| 27 | `routing/parallel-and-intercepting-routes` | ⚪ | |
| 28 | `routing/navigation-and-ui-state` | ⚪ | |
| 29 | `routing/instant-navigation-and-prefetching` | ⚪ | |
| 30 | `routing/error-handling-and-recovery` | ⚪ | |

## Wave 5 — Production (14)

| # | Slug | Status | Notes |
| --- | --- | --- | --- |
| 31 | `auth/session-and-authorization` | ⚪ | |
| 32 | `auth/proxy-and-the-network-boundary` | ⚪ | |
| 33 | `performance/the-client-bundle` | ⚪ | |
| 34 | `performance/images` | ⚪ | |
| 35 | `performance/fonts-and-cls` | ⚪ | |
| 36 | `performance/scripts-and-third-parties` | ⚪ | |
| 37 | `seo/metadata` | ⚪ | folder `docs/concepts/seo/` created |
| 38 | `seo/sitemaps-robots-and-structured-data` | ⚪ | |
| 39 | `deployment/isr-with-cache-components` | ⚪ | |
| 40 | `deployment/self-hosting-adapters-and-cache-handlers` | ⚪ | |
| 41 | `deployment/observability-and-instrumentation` | ⚪ | |
| 42 | `ecosystem/testing` | ⚪ | |
| 43 | `ecosystem/build-pipeline` | ⚪ | |
| 44 | `ecosystem/data-layer` | ⚪ | |

## Wave 6 — Migration (3)

| # | Slug | Status | Notes |
| --- | --- | --- | --- |
| 45 | `migration/fifteen-to-sixteen` | ⚪ | folder `docs/concepts/migration/` created |
| 46 | `migration/adopting-cache-components` | ⚪ | |
| 47 | `migration/pages-to-app` | ⚪ | |

---

## Recipe tracks (domain order — not A–I)

| Track | Status |
| --- | --- |
| `caching/` | ⚪ closed until gating articles land |
| `rendering/` | ⚪ |
| `data-fetching/` | ⚪ |
| `mutations/` | ⚪ |
| `auth/` | ⚪ |
| `routing/` | ⚪ |
| `performance/` | ⚪ |
| `migration/` | ⚪ |
| `deployment/` | ⚪ |

---

## Demo confirmation backlog (from Wave 1 drafts)

Copied from each article's **Verification status** block. These are the next
demo-route jobs — not article prose work.

### `foundations/thinking-in-the-app-router`

- [x] Exact build-error text for synchronous IO — measured §8.4 (see session 3 log)
- [x] Observable prerender status line for `/products/[slug]` in `next build` output — `◐` Partial Prerender; three slugs listed + catch-all `[slug]`
- [ ] Whether `notFound()` inside a `<Suspense>`-wrapped child behaves identically to the page-level call under `catchError`
- [ ] Replace authored code blocks via extraction from `demos/next-lab/app/products/[slug]/` + `lib/catalog.ts`

### `caching/cache-components-model`

- [x] Exact build-output line proving alerts left the prerender in Step 5.3 — measured §8.5 (`cacheLife('seconds')` → absent from `.next/server/app/dashboard.html`; `'minutes'` → present)
- [x] Cross-user leak vector — measured §7: A runtime-errors (no leak); B module var **leaks**; C coarse key **leaks**. Files retained under `lib/billing-leak-*.ts` + `app/leak-*`
- [x] Insights absent from HTTP — measured via `app/insight-probe/` (HTTP 200 + `blocking-prerender-dynamic` in `next dev` log; not in body). Overlay/MCP still TODO
- [x] Converted to `.md.tpl`; 23 sourced blocks; `--strict` green; induced drift on `billing.ts#getPlans` → exit 1 with file:line
- [ ] DevTools MCP / overlay confirmation of the insight surface (log-only so far)

### `foundations/server-and-client-components`

- [x] Bundle method without First Load JS — `entryJSFiles` from client-reference manifest; stage deltas recorded (noise); `_stages/` not in build table
- [ ] Exact error text for importing a Server Component into a Client Component under Turbopack
- [ ] Whether the RSC payload node shape in "How it works" should be a real captured payload fragment
- [ ] Replace authored code blocks via extraction from `demos/next-lab/app/catalog/` (`_stages/` + stage-4 `page.tsx`)

### `foundations/build-time-request-time-and-the-client`

- [x] Exp1 — four sync-IO primitives error identically (`observations/sync-io-variants.txt`)
- [x] Exp2 — `instant = false` does not clear sync-IO (`observations/instant-false-syncio.txt`)
- [x] Exp3 — `new Date()` in `'use cache'` builds/runs/freezes (`observations/date-in-cache-scope.txt`)
- [x] Exp4 — `after()` ordering + visitor total ≪ 300ms (`observations/after-ordering.txt`)
- [x] Cached-timestamp section landed (`lib/stamped.ts`); article at `status: review`
- [x] Session-6 corrections: `insight-vs-build-error.txt`; severity claim falsified+rewritten in articles 4 + 6 + roadmap §5; sync-IO unified as one rule

---

## Open questions / TODOs

- [ ] Register Next.js DevTools MCP — insights never appear in the HTTP response; until wired, insight work is manual overlay-reading only (`.cursor/mcp.json.todo`)
- [ ] Wave 6 consequence: `cache-components-instant-false` codemod takes `./app` (no `src/`); check the `ok` count — wrong path reports `0 ok` silently
- [ ] Choose a real test runner for `next-lab` (currently `node --test` placeholder)
- [ ] eslint-config-next peer range still `<6.1.0` while demo uses TypeScript 7 — track upstream
- [ ] Filesystem-cache wording not separately printed in `next build` log (Turbopack confirmed)
- [ ] Approve `roadmap.md` checklist (still unchecked by design)

### Article 43 material — TypeScript 7 + `next build` (do not rediscover)

Recorded 2026-08-10 from the official `useTypeScriptCli` reference and the bump session:

- **No config required for TS 7.** The project-local `tsc` CLI is the default checker. `experimental.useTypeScriptCli` is an opt-*out* (`false` → TS JS API); experimental; not recommended for production.
- **Side-by-side install trap.** TS 7 can sit beside TS 6: `node_modules/typescript` may remain 6 while 7 lives elsewhere; `npx tsc` is the Go compiler and `tsc6` the old one. Delete `node_modules` + lockfile before reinstalling, or resolution looks like a Next bug.
- **Native diagnostics only.** CLI checking prints raw `tsc` output — no Next code frames, no route/page/layout rewriting. It type-checks the **complete** `tsconfig` project, including test files and `.next/dev/types` when included.
- **`typescript.ignoreBuildErrors` skips the CLI checker too.**

---

## Session log

### 1 — 2026-08-10 — scaffolding

- Verified registry versions: next `16.3.0`, react `19.2.8`, typescript `7.0.2`, node `v22.22.0`, pnpm `10.33.0`.
- Created directory tree, templates, evolution ledger, CI, and verify scripts (links + legacy implemented; code-blocks / build-article stubbed `NOT PORTED`).
- Ran `pnpm create next-app@latest next-lab` with flags:
  `--typescript --eslint --app --use-pnpm --disable-git --skip-install --yes --import-alias "@/*"`.
- **Prompts / defaults:** `--yes` accepted create-next-app defaults. No interactive prompts appeared. Template selected: `app-tw` (App Router + Tailwind v4). `--src-dir` omitted → app at `app/`. `--agents-md` default on → demo `AGENTS.md` + `CLAUDE.md` present. Tailwind enabled by default (no `--no-tailwind` flag in this CLI).
- Set `cacheComponents: true` in `demos/next-lab/next.config.ts`.
- Nested `demos/next-lab/pnpm-workspace.yaml` (ignoredBuiltDependencies only) removed; `pnpm.ignoredBuiltDependencies` registered on the **root** `package.json` (pnpm warned package-level config is ignored in a workspace).
- Node baseline locked to observed `22` (assumed 24 LTS was wrong for this host). TypeScript demo pin left at create-next-app `^5` (resolved `5.9.3`) despite registry `7.0.2`.
- `pnpm --filter next-lab build` succeeded: Turbopack + `Cache Components enabled`.
- Legacy gate proven: scratch `.md` with `export const dynamic = 'force-dynamic'` → exit 1; deleted; exit 0.

### 2 — 2026-08-10 — reconcile

- Replaced scaffold roadmap with delivered revision 2 (47 articles, Waves 1–6, domain recipe tracks). Applied §1 corrections: Node 22; React framed as repo stance; **TypeScript bumped to `7.0.2`** with `experimental.useTypeScriptCli: true` — build passed (`create-next-app` still pins `^5`; eslint-config-next peers warn `<6.1.0`).
- Installed `scripts/lib/extract.mjs`, real `verify-code-blocks.mjs`, real `build-article.py`. Fixed Windows `isMain` detection in extract CLI (`fileURLToPath` + `resolve`). Fixed `verify-code-blocks` frontmatter parse for BOM/CRLF.
- CI order: `build-article --check --all` → `verify-code-blocks --strict` → links → legacy → demo build → demo test.
- Placed three Wave 1 drafts; copied Verification-status pending items into the demo backlog above.
- Created `docs/concepts/seo/.gitkeep` and `docs/concepts/migration/.gitkeep` (rev-2 paths; `seo/metadata` not `routing/metadata`).
- Rebuilt this file's wave tables against **47** articles — no Wave 0, no tracks A–I, no rev-1 numbering.
- Resolved evolution-ledger Cite column against bundled `next@16.3.0` docs (all 22 rows cited; dynamicParams/`notFound()` nuance noted in the ledger).
- Gate softening so draft corpus can land without rewriting prose: missing forward/sibling links warn; legacy hits in `status: draft` warn; still-live APIs (`cookies()`, `headers()`, `searchParams`, …) excluded from the ban list after ledger parse.

### 2b — 2026-08-10 — session 2 corrections

- Removed no-op `experimental.useTypeScriptCli: true` from `next.config.ts`. Roadmap §1 reworded: TS 7 needs no config; flag is opt-out only.
- Recorded TS 7 gotchas under Open questions as article-43 material.
- Reverted legacy draft-softening; extended allowed headings with `common mistakes`; Ban column owns the ban list (hardcoded STILL_LIVE deleted).
- Link gate keeps warn-on-draft; header comment distinguishes the two policies.

### 3 — 2026-08-10 — Wave 1 demo routes

- In-memory `lib/db.ts` (ORM deferred). Config: `cacheComponents` + `partialPrefetching`. Routes: `products/[slug]`, `catalog` (+ `_stages`), `dashboard`, leak A/B/C. Legacy before-state at `legacy/dashboard-page.next15.tsx` (tsconfig excluded).
- §7 leak table: A builds, runtime error (no leak); B builds+runs+**leaks**; C builds+runs+**leaks**. Files kept.
- §8: route table `◐` PPR; sync-IO exact error recorded; alerts leave prerender under `cacheLife('seconds')`; no First Load JS column in 16.3 build table; no validation insights in `next dev` log for the three Wave 1 routes (all 200).

### 3b — 2026-08-10 — legacy-ok regions

- Added third allowed form `<!-- legacy-ok:start reason=… -->` / `end` to `verify-legacy-markers.mjs` (mandatory reason; fail on missing/unclosed/nested; summary + `--verbose`).
- Article 6: Step 0 fence got `// legacy:` marker; four-layer table + `experimental.ppr` bullet wrapped in regions. Gate: `0 failure(s); 2 legacy-ok region(s) across 1 file(s)`.
- Documented in `AGENTS.md` and roadmap §5.

### 3c — 2026-08-10 — article corrections from session 3 measurements

- §1: leak story rewritten (caught `cookies()` vs B/C); key wording tightened (no "closes over"); recipe #2 arc respec'd in roadmap; six leak files retained.
- §2: shell verification → `.next/server/app/<route>.html` in all three walkthroughs; roadmap §5 measurement standard updated.
- §3: article 2 drops First Load JS; method = `entryJSFiles` from `page_client-reference-manifest.js` (no `app-build-manifest.json` under Turbopack); stages noted as `_stages/` private; measured deltas 551/452/445 B — not a meaningful KB table; script `demos/next-lab/scripts/measure-catalog-stages.mjs`.
- §4: demo-source paths → `legacy/dashboard-page.next15.tsx` and `_stages/stage{1,2,3}-*`.
- §5: sync-IO + lifetime claims promoted to measured; article 10 note in roadmap about route-level `1d/1w` vs per-entry lifetime.
- §6: `app/insight-probe/` — with blocking form, HTTP 200 + log `blocking-prerender-dynamic` (claim kept, measured); shipped with `instant = false` so `next build` stays green (remove locally to re-trigger).

### 4 — 2026-08-10 — template conversion (article 6)

- Added `demos/next-lab/antipatterns/` (tsconfig-excluded), `observations/` (recorded outputs), `app/basic/` (Announcements + PersonalStats).
- Did **not** duplicate `identity-in-cached-scope.ts` — extract from `billing-leak-a.ts` per prompt.
- Converted `cache-components-model.md` → `.md.tpl`; `status: review`; 23 sourced fences; bash `#12` stays authored (verifier allows `bash`/`sh`/`shell` under `--strict`).
- Pipeline fixes found in-session: `build-article.py` must use `encoding=utf-8` on Windows; `.txt` → fence lang `text`.
- Drift proof: mutate `cacheTag('plans')` → exit 1 naming `…#getPlans` + line; restored.
- Full gate chain green; `/basic` builds as `◐`.

### 4b — 2026-08-10 — session 4 follow-ups

- Extractor: symbol extracts prepend used imports; `#<symbol>-imports` opts out. Ambiguity policy: prefer false positive (emit import) — regex literals are not tokenised, so an identifier inside `/Name/` counts as a use. Fixtures: type-only `Product` matched; `cacheLife` only in string/comment did not. Fixtures deleted after run.
- `verify-code-blocks` summary now `N sourced / M unsourced-shell / K unsourced-other … failure(s)`.
- Roadmap §5: `.tpl`-first rule; demo-sources-are-content; batched observations.
- Article 6: "one config line" → "one decision"; `instant = false` silence sentence already present.

### 5 — 2026-08-10 — article 5 demos (`.tpl`-native)

- Sources: `lib/db.ts` report latencies; `lib/report.ts`; `app/streaming/` + `app/streaming-coarse/`; `antipatterns/mismatched-fallback.tsx`.
- Observation batch (6 files): both predictions **confirmed**. Fine shell = summary + 3 skeletons; coarse shell = one skeleton only, no `2026-W32`. Both routes still `◐`.
- Timings: `/streaming` TTFB 0.08s / total 1.62s; `/streaming-coarse` TTFB 0.03s / total 1.55s.
- Template built; gates green (`32 sourced`). Remains `status: draft` pending review.
- End-to-end wall time ≈ **15–20 minutes** (sources + one observe script + build/gates) — `.tpl`-native is dramatically cheaper than session-4 conversion.

### 5b — 2026-08-10 — article 5 timing corrections

- Step 5 rewritten: TTFB/totals cannot distinguish fine vs coarse; content between them can (one `$RC` vs three).
- `◐` caveat in Real-world patterns + roadmap §5 measurement standard.
- Mistake #2, Summary bullet 4, Exercise 3 sharpened.
- Verification status: predictions 1–2 measured; old "nothing until slowest" claim recorded as falsified-and-rewritten. `status: review`.
- Workflow locked: `.tpl`-native for 3, 4, 7, 8+. Conversion debt: article 1 (cheap), article 2 (blocked on payload measurement).

### 6b — 2026-08-10 — session 6 corrections

- Captured `observations/insight-vs-build-error.txt`: bare `connection()` → HTTP 200 + log `Error:` in `next dev`; `next build` exit 1 on same `blocking-prerender-dynamic`. Log never says "Insight."
- **Falsified:** articles 4 + 6 severity ladder ("insights don't stop builds"). Rewritten around **dev under-reports severity**; HTTP-body absence kept as the weaker half. Same fix in roadmap §5 measurement standard.
- Sync-IO Exp1+Exp3 unified as one observational rule (refused where nothing bounds staleness; permitted where `cacheLife` does); bounded-staleness reading marked as inference. Cached-timestamp trap adds lifetime-scaling hazard; both measured timestamps kept in extract.
- Article 4 → `status: review`. Do not rediscover the severity correction when next touching article 6 — already applied.

### 6 — 2026-08-10 — article 4 demos (`.tpl`-native)

- Sources: `lib/when.ts`, `lib/stamped.ts`, `lib/audit.ts`, `app/when/`, `app/after-demo/` (Suspense around `connection()` — bare root failed build), antipatterns `sync-io-variants` + `instant-false-doesnt-help`.
- Observation batch via `scripts/session6-observe.mjs` (unique public scratch routes; do not use `_`-private folders; do not wipe `.next` mid-run on Windows).
- Exp1: all four sync-IO primitives caught. Exp2: `instant=false` does not clear. Exp3: `new Date()` in `'use cache'` **builds + runs + freezes** — section "Cached timestamps are legal — and a trap" added. Exp4: `[render]` then `time_total≈0.24s` then `[audit]` (~436ms after queue).
- Template built; gates green; demo build green (`/when`, `/after-demo` as `◐`). Ships `status: draft`. Clean observe pass ≈ **80s**; wall time inflated by concurrent orphan builds/locks — compare to session 5’s 15–20 min once tooling is quiet.
