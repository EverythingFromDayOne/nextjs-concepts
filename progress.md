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
| 2 | `foundations/server-and-client-components` | 🟢 | `status: draft`; `.tpl`-native (session 8); payload cost + silent conversion measured |
| 3 | `foundations/file-conventions-and-the-route-tree` | ⚪ | |
| 4 | `foundations/build-time-request-time-and-the-client` | 🟢 | `status: review`; Exp1–4 measured; severity claim falsified+rewritten; sync-IO one-rule |
| 5 | `rendering/static-shell-and-streaming` | 🟢 | `status: review`; predictions measured; TTFB framing corrected |
| 6 | `caching/cache-components-model` | 🟢 | `status: review`; `.md.tpl` extraction pipeline proven |
| 7 | `rendering/client-side-rendering` | 🟢 | `.tpl`-native from session start; all three experiments resolved in one pass |
| 8 | `foundations/rules-of-the-server-boundary` | 🟢 | `status: draft`; eleven-probe enforcement matrix measured in full; template converted `.tpl`-native from session start (moved from `prompts/session7/` per the new staging convention) |

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
| `caching/` | 🟡 open — `user-a-sees-user-b-data` `status: draft`, landed session 11 |
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
- [x] Exact error text for importing a Server Component into a Client Component under Turbopack — measured session 7 (article 8, probe 8): no error at all if the component has no server-only content (silently reclassified as client code); `You're importing a module that depends on "next/headers" into a React Client Component module …` if it uses a Node-only API; the generic `blocking-prerender-dynamic` error if it does uncached, unsuspended data access. There is no error specific to "Server Component imported into Client Component" as such.
- [x] Class instance across the client boundary — measured session 7 (article 8, probe 10): hard build failure (`Only plain objects, and a few built-ins, can be passed to Client Components from Server Components. Classes or null prototypes are not supported.`), **not** the silent fields-arrive/methods-`undefined` degradation this article previously assumed. Corrected in this article (`How it works under the hood` + Common mistake #6) in the same change that landed article 8.
- [x] Payload cost across the boundary — measured session 8: `payload-a-{40,4000}` (prop into `Stage2List`) vs `payload-b-{40,4000}` (`children` through `FilterShell`/`ProductRow`); bundle (`entryJSFiles`) near-identical (15,100 B vs 15,093 B) at both scales; RSC-payload-only bytes (isolated via a scratch rebuild with `experimental.validateRSCRequestHeaders: false` and the `rsc: 1` header) diverge 1.37× at 40 products, 1.74× at 4,000 — real, linear, driven by unused fields (`id`/`slug`/`description`) riding along in the raw prop array, not by an order-of-magnitude gap the pre-measurement article implied. `observations/payload-boundary.txt`.
- [x] Silent conversion, made visible — measured session 8: `convert-a` (children) vs `convert-b` (direct import of `ProductRow`, no server-only content) both build silently; `convert-b`'s bundle grows by exactly `ProductRow`'s inlined code (274 B), the only trace. `import 'server-only'` in `product-row.tsx` converts that into a named build failure every time — unconditionally, because it's a bundler import-graph check, not a render-time one (unlike the phase-dependent class-instance/`cookies()` checks). `observations/silent-conversion.txt`.
- [x] Replace authored code blocks via extraction from `demos/next-lab/app/catalog/` (`_stages/` + stage-4 `page.tsx`) — converted `.tpl`-native this session; `server-and-client-components.md` is now a build artifact.
- [ ] Whether the RSC payload node shape in "How it works" ("How it works under the hood" → "The RSC payload is not HTML") should be a real captured payload fragment — still illustrative pseudocode; not addressed this session.

### `foundations/build-time-request-time-and-the-client`

- [x] Exp1 — four sync-IO primitives error identically (`observations/sync-io-variants.txt`)
- [x] Exp2 — `instant = false` does not clear sync-IO (`observations/instant-false-syncio.txt`)
- [x] Exp3 — `new Date()` in `'use cache'` builds/runs/freezes (`observations/date-in-cache-scope.txt`)
- [x] Exp4 — `after()` ordering + visitor total ≪ 300ms (`observations/after-ordering.txt`)
- [x] Cached-timestamp section landed (`lib/stamped.ts`); article at `status: review`
- [x] Session-6 corrections: `insight-vs-build-error.txt`; severity claim falsified+rewritten in articles 4 + 6 + roadmap §5; sync-IO unified as one rule

### `foundations/rules-of-the-server-boundary`

- [x] All eleven probes run serially, one at a time, each isolated by a full build cycle — `observations/enforcement-matrix.txt`
- [x] Probe 8 (Server Component imported into a Client Component) re-run with two extra variants after the first pass returned a generic, boundary-unrelated error — no-server-API case builds clean and ships silently; `next/headers` case fails with a named, specific error
- [x] Probe 9 (function prop across the boundary) re-run with a non-event-handler-named prop — confirms the error message is name-sensitive (`onClick` → the DOM-event-handler message; anything else → the generic function-serialization message), not just type-sensitive
- [x] Probe 10 (class instance across the boundary) — resolved: hard build failure, not silent. Corrects `foundations/server-and-client-components` in the same change
- [x] §3 route-lifetime-column probe — resolved (not left ambiguous): the Revalidate/Expire column tracks the shortest lifetime among `'use cache'` entries actually evaluated during the route's build-time prerender pass, regardless of whether that entry's content lands in the visible shell. Roadmap §3 article-10 note updated with the resolved mechanism.
- [x] Four antipattern files kept (`non-async-cached-fn.ts`, `hooks-in-server-component.tsx`, `imported-server-component.tsx`, `class-instance-prop.tsx`), each with a measured `// fails:` line
- [x] §5 housekeeping: "insight"-as-severity usage already corrected in session 6, nothing left to change; article 4 gained one sentence on `instant = false` costing the segment its shell (`ƒ` Dynamic, not `◐`), measured against `/insight-probe`; roadmap article-10 note upgraded with the resolved §3 mechanism

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

### 7 — 2026-08-10 — article 8 demos (eleven-probe enforcement matrix)

- Template started life at `prompts/session7/rules-of-the-server-boundary.md.tpl` per the new staging convention (roadmap §5), moved into `docs/concepts/foundations/` as the session's final step, once all `{EXTRACT:}` targets existed.
- All eleven probes run serially via `demos/next-lab/scripts/session7-observe.mjs` (one violation at a time: write → `pnpm build` → capture → if it built, `next start` + `curl` → capture → remove). Linux port-kill required two hardening passes: `next start` spawns a detached `next-server` grandchild that neither `lsof -ti` nor a plain `child.kill()` reliably reaches in this sandbox, so port readiness is now a real bind-attempt (`net.createServer().listen()`), and the child is killed via its process group (`spawn(..., { detached: true })` + `process.kill(-pid, …)`).
- Probes 1, 2, 4, 6, 7, 11 all fail at build with specific, named errors. Probe 3 (reused, reconfirmed) and probe 5 (reused, reconfirmed) unchanged from sessions 3/6. Probes 8–10 needed follow-up variants — see below.
- **Probe 8 doesn't collapse to one verdict.** The original design (async component doing an uncached `db` call) failed at build, but via the generic `blocking-prerender-dynamic` error, unrelated to the client boundary. Two more variants isolated the real rule: a directive-less component with no server-only content, imported into a Client Component, **builds and ships silently** (its code is inlined into the client bundle with no separate manifest entry and no warning); the same shape using `next/headers` fails with a specific "only available in Server Components" error. There is no check that says "a Server Component may not be imported into a Client Component" — only "a module reachable from the client import graph runs on the client."
- **Probe 9's message is name-sensitive.** A function prop named `onClick` gets the DOM-event-handler-specific error; the identical function under a different name gets the generic function-serialization error. Both are build failures.
- **Probe 10 resolved the article's open question: not silent.** `Error: Only plain objects, and a few built-ins, can be passed to Client Components from Server Components. Classes or null prototypes are not supported.` — a hard build failure, not the fields-arrive/methods-`undefined` degradation both this article and `foundations/server-and-client-components` had assumed. Corrected both articles in the same change.
- §3 follow-up resolved (not left ambiguous): added a second, shorter-lived `'use cache'` entry to `/streaming-coarse`; the Revalidate/Expire column moved from `1h 1d` to `1m 1h`, confirming it tracks the shortest lifetime among entries actually evaluated during the build, independent of shell membership. Roadmap §3 article-10 note rewritten with the resolved mechanism.
- Four antipattern files kept (probes 1, 6, 8, 10), each with a measured `// fails:` line; all scratch routes and libs removed after each probe. §5 housekeeping: "insight"-as-severity already fixed in session 6 (nothing to change); one sentence added to article 4 on `instant = false` costing the segment its shell entirely (`ƒ` Dynamic).
- Full gate chain green: `verify:templates`, `verify:code-blocks --strict` (0 failures, 10 files), `verify:links` (0 hard failures), `verify:legacy`, demo build, demo test.

### 8 — 2026-08-14 — article 2 rewrite (`server-and-client-components`), `.tpl`-native

- Article 2 was the last Wave 1 draft carrying hand-written code and the last block on conversion debt (roadmap §5). This session **replaced** it rather than patched it, per three session-7 findings the draft predated: class-instance failure is phase-dependent, not a flat build error; importing a server-only-free Server Component into a Client Component is silent, not loud; enforcement phase wasn't discussed at all.
- **Experiment A — payload cost, the article's central claim, unmeasured until now.** Added `makeProducts(n)` to `lib/db.ts`; four scratch routes (`payload-a-{40,4000}` reusing `Stage2List`, `payload-b-{40,4000}` reusing `FilterShell`/`ProductRow`), same visible output, differing only in prop-vs-`children`. Bundle (`entryJSFiles`) confirmed near-identical at both scales (15,100 B vs 15,093 B) — the control. Total HTML response size alone couldn't isolate the claim (both shapes render the same list, so HTML scales similarly); separated the RSC payload from HTML by rebuilding once with `experimental.validateRSCRequestHeaders: false` (bundled-docs-confirmed, `cdn-caching.md`) and curling with `rsc: 1` — real separation, not an estimate. Result: **the claim's direction holds, its magnitude doesn't** — 1.37× at 40 products, 1.74× at 4,000, driven by unused fields (`id`/`slug`/`description`) carried in the raw prop array, not the dramatic gap the pre-measurement draft implied. Reported plainly rather than rounded up. `demos/next-lab/scripts/session8-observe.mjs` (mode `payload`); `observations/payload-boundary.txt`.
- **Experiment B — the silent conversion, made visible.** Two scratch routes: `convert-a` (children, correct) vs `convert-b` (direct import of `ProductRow`, which has no server-only content). Both build silently; `convert-b`'s bundle grows by exactly `ProductRow`'s inlined code (274 B) — the only trace, and only visible in the manifest, never as its own entry. Adding `import 'server-only'` to `product-row.tsx` converts the identical import into a named, unconditional build failure (`You're importing a module that depends on "server-only" into a React Client Component module`) — unconditional because it's a bundler import-graph check, not a render-time one, unlike the phase-dependent class-instance/`cookies()` checks elsewhere in the article. `session8-observe.mjs` (mode `convert`); `observations/silent-conversion.txt`. `product-row.tsx` and `next.config.ts` restored after each experiment; both scratch route pairs deleted.
- Verified `antipatterns/imported-server-component.tsx`'s `// fails:` line already correctly framed the silent-vs-loud split (no change needed). Corrected `antipatterns/class-instance-prop.tsx`'s `// fails:` line to state the phase-dependence instead of a flat "build" — this file is shared with article 8 (`rules-of-the-server-boundary`), so that article's `.md` was rebuilt in the same change (`build-article.py --all`) to stay in sync; no prose in article 8 needed to change, only the extracted comment.
- Moved `prompts/session8/server-and-client-components.md.tpl` into `docs/concepts/foundations/`, replacing the old hand-written `.md` outright (not patched). Full gate chain green: `verify:templates` (7 templates, 0 drift), `verify:code-blocks --strict` (97 sourced / 7 unsourced-shell / 2 unsourced-other, 0 failures), `verify:links` (0 hard failures), `verify:legacy` (0 failures, 2 legacy-ok regions), demo build (`○`/`◐` unchanged for all real routes), demo test. Ships `status: draft` — one open item remains (the RSC payload node shape in "How it works" is still illustrative, not a captured fragment).

### 11 — 2026-08-13 — recipe #2 demos (`caching/user-a-sees-user-b-data`) — first recipe, first use of `RECIPE_TEMPLATE.md`

- Built the fix side: `lib/authz.ts` (`assertCanViewUsage`, deliberately uncached) and `app/leak-fixed/` (reuses `getUsage` from `lib/billing.ts`; reads `uid` outside every cached scope, authorizes, then calls the cached read). Both build as `◐`, same shape as `/leak-b`/`/leak-c` — the fix costs nothing structurally.
- Probed the alternative: `lib/billing-private.ts` (`'use cache: private'`) + `app/leak-private/`. `scripts/session11-observe.mjs` measured all four questions: builds with no flag beyond `cacheComponents`; `cookies()` is permitted (no throw, unlike plain `'use cache'`); does **not** leak two different cookies; provides **no server-side caching at all** — the artificial 400ms `db.usage.forUser` delay was paid on every request, matching `use-cache-remote.md`'s comparison table (`'use cache: private'` server-side caching = None). Framed in the recipe as a legitimate non-leaking answer that isn't a performance win here — an escape hatch, not a substitute for Step 4.
- Detection probe: `next build`'s route table gives `/leak-b` and `/leak-fixed` the identical `◐` annotation; `next dev`'s log shows only ordinary access lines for both, no diagnostic. **Negative result, stated as the finding**: the framework cannot detect this bug class; the two-cookie test against a production build is the only check.
- `observations/leak-fix-proof.txt` and `observations/private-cache-probe.txt` (Experiment B + Detection, split by line range for the two template placeholders) captured via the new observe script, following the session6/7 build/start/curl/kill-port pattern.
- Filled `prompts/session11/user-a-sees-user-b-data.md.tpl`'s three placeholders with `{EXTRACT:}` tokens against the new observation files, moved it to `docs/recipes/caching/`, rebuilt it, and added its row to `docs/recipes/index.md`. Full gate chain green (`verify:templates`, `--strict` code-blocks: 67 sourced, demo build, demo test). Ships `status: draft`.
- **Template report (first use of `RECIPE_TEMPLATE.md`):** every mandated section had something real to hold — nothing felt like filler. One gap: the template has no dedicated slot for a *negative* finding ("nothing can detect this") — it was placed under "Why it escaped QA" because that's where a reader needs it, but a template built around an assumed positive workaround would nudge an author toward overstating detectability instead. Frontmatter is sufficient as specified (`next_baseline: "16.3.0"` in the template itself, matching `verified_against`) — the session-10-authored draft had drifted to `"16.3"`, fixed here as a copy error, not a template defect. `recipe_id`, `primary_concept`, `difficulty` all did real classification work (this recipe's `primary_concept` was corrected from `caching/cache-components-model` to `caching/use-cache-directive` in `docs/recipes/index.md` to match the frontmatter it ships with).

### 11b — 2026-08-14 — `RECIPE_TEMPLATE.md`: "What doesn't work" section

- Added `## What doesn't work` to `RECIPE_TEMPLATE.md`, between `Variations` and `Trade-offs and pitfalls`: measured negative results — approaches that look like a fix and aren't, tooling that can't detect the problem. Inline comment says to omit the section entirely when there's nothing measured, not fill it with speculation.
- Moved recipe #2's two negative findings into it: the `'use cache: private'` probe (was in `Variations`, wedged between working alternatives that don't belong next to a rejected one) and the detection negative result (was appended to `Why it escaped QA` as an ad-hoc "fifth reason" that broke the section's own "four reasons" framing — restored to a clean four).
- **Preferred placement: the new section, for both.** `Why it escaped QA` reads better short and focused on QA-specific blind spots (one user, cache misses, no error surface, the caught-vs-not split); the detection finding is a claim about the framework in general, not about QA process, and forcing it in there required an apologetic "a fifth reason belongs here" sentence that the dedicated section makes unnecessary. `Variations` lists things that vary correctly; the private-cache probe is a rejected candidate, not a variation, and sat oddly next to `'use cache: remote'` implying they're peers. Grouping both negatives together also reads as a stronger unit — "here's what doesn't work, and here's why you can't just find that out yourself" — than either did split across two sections built for other purposes.
- Rebuilt; full gate chain green (`verify:templates`, `--strict` code-blocks: still 67 sourced, `verify:links`, `verify:legacy`), demo build + test green (unaffected, docs-only change).

### 9 — 2026-08-14 — article 7 demos (`rendering/client-side-rendering`), all four answers now owned

- Built `app/sketchpad/` (`sketchpad.tsx` + `page.tsx`) and `app/client-only/` (`heavy-widget.tsx`, `loader.tsx`, `page.tsx`) verbatim from the prompt; both build `○ Static` and returned `200` under `pnpm build && pnpm start` + `curl`. Added `antipatterns/client-page-for-static-content.tsx` (tsconfig-excluded folder, no new exclusion needed).
- **Experiment A** (`observations/client-only-shell.txt`): read `.next/server/app/{client-only,sketchpad,catalog}.html` directly, never a response body. **Corrected a working assumption**: the template's draft prose claimed sketchpad's `<canvas>` is absent from the shell like the widget's output — measured, the `<canvas>` tag *is* present (empty: no `width`/`height`, "0 strokes"). The real asymmetry is hydration-deferred (tag ships, empty) vs. `ssr: false` (nothing ships, fallback stands in), not prose-vs-canvas. Also recorded as found: `catalog.html` has no `<main>` at all (bare `<Suspense>`, no landmark) — used its fully-resolved `<input>`/`<ul>` body as the contrast instead of forcing a `<main>` comparison that doesn't exist. Crawler-behaviour limit stated explicitly in the file's provenance line and repeated in the article prose.
- **Experiment B** (`observations/ssr-false-in-server-component.txt`): scratch route `app/scratch-ssr-false-server/page.tsx` calling `dynamic(..., { ssr: false })` directly in a Server Component → `pnpm build` fails with a Turbopack compile error (`ssr: false is not allowed with next/dynamic in Server Components. Please move it into a Client Component.`), matching `node_modules/next/dist/docs/01-app/02-guides/lazy-loading.md` verbatim. **Confirms, not corrects**, the article's §2 assumption — the `loader.tsx` indirection is required. Scratch route deleted after capture; demo build reconfirmed clean.
- **Experiment C skipped** (`observations/query-double-fetch.txt`): adding TanStack Query for one demo page is exactly the invented-dependency category `roadmap.md` §7 exists to flag, and `roadmap.md` §2 already assigns that library to `reactjs-concepts`. Recorded the mechanism instead using the repo's existing `app/catalog/` promise-passed-to-`use()` baseline: a Server Component's data crosses the boundary once, serialized into the payload; a client fetch against a route handler for the same data is a second, independent request. No new dependency added.
- Filled all three placeholders (`{SSR_FALSE_IN_SERVER}`, `{SHELL_COMPARISON}`, `{QUERY_RESULT}`) from the three observation files above, moved `prompts/session9/client-side-rendering.md.tpl` → `docs/concepts/rendering/`, rebuilt. Full gate chain green: `verify:templates`, `verify:code-blocks --strict` (89 sourced / 9 unsourced-shell / 18 unsourced-other, 0 failures), `verify:links` (0 hard failures), `verify:legacy` (0 failures), demo build, demo test. Ships `status: draft`.
