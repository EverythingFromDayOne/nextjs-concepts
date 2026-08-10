---
document: roadmap
revision: 2
revised_on: 2026-08-09
supersedes: revision 1 (42 articles)
---

# nextjs-concepts — roadmap

Planning document. See [`README.md`](README.md) for the reader-facing entry point and [`progress.md`](progress.md) for what has actually landed.

**Revision 2** folds in two things: the versions Cursor observed during scaffolding (which beat the assumed ones), and a gap analysis against a representative 2026 Next.js course syllabus, which added five articles and exposed a hole in the four-answer model. **Nothing below is final until the approval checklist at the bottom is signed off.**

---

## 1. Locked baseline

Every version below was read from the npm registry or from official release material on **2026-08-09**, and cross-checked against what Cursor observed in the scaffolded `demos/next-lab`. Where the two disagreed, **the observation wins** — three corrections are marked.

| Thing | Baseline | Source / note |
| --- | --- | --- |
| Next.js | **16.3.0** | `latest` on the registry; canary `16.3.1-canary.9`. Stable 2026-08-03. |
| `create-next-app` | **16.3.0** | Observed at scaffold time. |
| React / React DOM | **19.2.8** | ⚠️ **Corrected framing.** This is a *repo stance*, not a framework floor — `next@16.3.0`'s peer range is `^18.2.0 \|\| ^19.0.0`. We target 19.2 because `<Activity>` and current `use()` semantics need it. |
| Node | **22 (`engines: >=22`)** | ⚠️ **Corrected.** Revision 1 assumed 24 LTS. Observed `v22.22.0`, independently confirmed `v22.22.2`. Cache Components requires the Node.js *runtime*, not a specific major. |
| TypeScript | **7.0.2** | ⚠️ **Corrected.** `typescript@^7` installed in `demos/next-lab`; `pnpm --filter next-lab build` passed. **No configuration required** — the project-local `tsc` CLI is the default checker. `experimental.useTypeScriptCli` is an opt-*out* (set `false` to use the TS JS API); it is experimental and not recommended for production. `create-next-app` still pins `^5` — CLI lags the registry. eslint-config-next peers still declare `<6.1.0` (warning only). |
| Router | **App Router only** | Pages Router appears only in `migration/pages-to-app`. |
| Caching | **`cacheComponents: true`** from day one | Dynamic by default; opt in with `'use cache'`. |
| Prefetching | **`partialPrefetching: true`** from day one | Opt-in in 16.3; stated to become default in a future major. *(invented — §7.1)* |
| Bundler | **Turbopack** — default for `dev` and `build`; filesystem cache on by default in 16.3 | Webpack is not taught. |
| Package manager | **pnpm 10.33.0**, workspaces, root-owned | Nested workspace file removed during scaffolding. |
| Directory layout | **No `src/`** | Consequence for Wave 6: the `cache-components-instant-false` codemod takes `./app`, and reports `0 ok` rather than erroring on a wrong path. |
| DB / ORM (demos) | **Drizzle + PostgreSQL 18** | *(invented — §7.2)* |
| Testing | Vitest + RTL; Playwright + `@next/playwright@16.3.0` `instant()` | The `instant()` helper is 16.3. |
| Styling | Tailwind v4 (`create-next-app` default), used but not taught | `reactjs-concepts` owns styling. |
| Licence | Dual: CC-BY prose + MIT code | Matches `nestjs-concepts`. |

**Frontmatter stamp convention:** every article carries `verified_against: next@16.3.0` and `verified_on: YYYY-MM-DD`. This ecosystem moves fast enough that an undated claim is a liability, and the stamp is what makes a future re-verification pass tractable. *(invented — §7.3)*

---

## 2. Stance

### The thesis — the stale-answer tax

Almost every Next.js tutorial, StackOverflow answer, blog post, and LLM completion in existence was written against Next 13–15, where the framework cached aggressively by default and you opted *out*. Next 16 inverted that: everything is dynamic by default and you opt *in* with `'use cache'`.

The same code, unchanged, now means the opposite thing. Advice that was correct two years ago is not merely outdated — it silently produces wrong caching behavior, and the failure is invisible in `next dev`.

Vercel ships a guardrail against exactly this: `next dev` writes a version-matched `AGENTS.md` block pointing at docs bundled inside `node_modules/next/dist/docs/`, opening with the line that this is not the Next.js the agent knows. A framework that has to warn tooling about its own training data is the strongest possible argument for this repo existing.

This is the structural equivalent of the **JS tax** in `dsa-concepts`: a systematic, measurable way that the available material is wrong, called out in every article rather than mentioned once.

**Consequence: the "Then vs now" section is mandatory on every article** (§5), backed by `docs/evolution-ledger.md` and enforced in CI by `verify-legacy-markers.mjs`.

### Corroborating evidence, and what we do about it

A representative 2026 Next.js course syllabus (46 lessons) organizes its rendering section as **four strategies you choose between** — CSR, SSR, SSG, ISR, plus a static-vs-dynamic binary — and its data section as **four cache layers you learn separately**: Request Memoization, Data Cache, Full Route Cache, Router Cache. Cache Components appears as lesson 32 of 46, bolted onto the end of the caching section as one more feature.

That is the retired model taught in full, with its replacement added as a topic. It is the cleanest external confirmation of the thesis available.

Our response has two halves:

- **Cover every topic.** All 38 lessons audited are owned; the five that weren't became articles 7, 23, 34/35, 36, and 38.
- **Reject the organization.** There is no `rendering-strategies-overview` article and no four-caches tour as a learning path, because reproducing that structure would reproduce the confusion. Readers arriving with that taxonomy get the **translation table** (§9) instead.

### Scope decisions

- **App Router only.** Pages Router is migration material, never a live alternative. No dual examples.
- **Cache Components on from day one.** Teaching the pre-16 implicit model as the baseline and Cache Components as "the new thing" would reproduce exactly the failure this repo exists to fix. The new model *is* the model; the old one lives in "Then vs now".
- **`'use cache: private'` is experimental** and carries an explicit experimental marker everywhere it appears. It never appears as the primary solution in a walkthrough — it is the escape hatch after "pass runtime data as arguments" has been shown and rejected for a stated reason.
- **Platform-neutral.** Where a claim is Vercel-specific (ISR observability, remote cache handlers, immutable asset reuse), say so. Self-hosting gets a real article, not a footnote.
- **Edge runtime is not taught.** `runtime = 'edge'` is deprecated and incompatible with Cache Components; `proxy.ts` is where edge-shaped work goes.

### Cross-repo position

`reactjs-concepts` §2 explicitly parked RSC: *"RSC coverage happens via Next.js App Router when we get there, since that's where RSC is actually usable in production."* **This repo pays that debt.** Articles 2, 5, and 15 are the settlement.

Cross-repo links use `[text](../../../../reactjs-concepts/docs/concepts/<path>.md)` — **four** `../`, not two — and are excluded from `verify-links.mjs` resolution when the sibling repo isn't checked out — the script warns rather than fails. *(invented — §7.5)*

**Depth derivation**, so nobody recomputes it wrong a third time. From `docs/concepts/<folder>/`, escaping to a sibling repo climbs:

```
docs/concepts/foundations/  →  docs/concepts/  →  docs/  →  <repo root>  →  experimental-projects/
```

Four levels — `docs/concepts/<folder>/` is three directories below the repo root, and the sibling repo sits one directory above the repo root. Three `../` lands back inside this repo (a same-repo failure, not a cross-repo link); four `../` is the first level that actually escapes it.

Deliberately **not** inherited from `reactjs-concepts`: hook-level teaching (`useState`, effects, keys, the Compiler-as-memoization story) and forms-at-scale. A reader arriving here is assumed to know React. Where a Next behavior depends on a React primitive, link sideways rather than re-teach.

---

## 3. Concept articles — priority order

**47 articles.** Numbering = **reading order**. Waves gate delivery; delivery order within Wave 1 deviates once (see §8).

### Wave 1 — The model (8)

1. `foundations/thinking-in-the-app-router` — **the anchor.** The request lifecycle as one picture: build-time prerender → static shell → stream the holes. `UI = f(request, cache)`. Why "dynamic" is now a property of a *boundary*, not a route. Everything references this. **Opus tier.** 🟢 *drafted*
2. `foundations/server-and-client-components` — the `'use client'` boundary as a *module-graph and network* boundary; what may cross it; why the boundary is a leaf-ward decision. Pays part of the RSC debt. 🟢 *drafted*
3. `foundations/file-conventions-and-the-route-tree` — `page` / `layout` / `template` / `loading` / `error` / `not-found` / `default` / `route`; nesting; what each convention actually buys under Cache Components.
4. `foundations/build-time-request-time-and-the-client` — what runs when. `connection()`, `after()`, why `new Date()` fails a prerender, and why `instant = false` doesn't rescue synchronous IO.
5. `rendering/static-shell-and-streaming` — PPR as the default architecture, not a flag. Suspense as the thing that *defines* the hole. Shell extraction. **Opus tier.**
6. `caching/cache-components-model` — **the thesis article.** The inversion, why it happened, and the four questions every piece of data must answer. 🟢 *drafted*
7. `rendering/client-side-rendering` — **the fourth answer.** When client-side is correct: device-local state, high-frequency interaction, editors and canvases, WebSocket-driven UI. `next/dynamic` with `ssr: false` and what "client-only" costs. TanStack Query alongside RSC — where it earns its place and where it duplicates a cache you already have. The SEO ceiling of a client-rendered page, as measurement rather than folklore. And an honest *when not to reach for Next at all*.
8. `foundations/rules-of-the-server-boundary` — the contract: what is legal in a cached scope, a Server Component, a Client Component, a Server Function. Framed the way `rules-of-react` is framed — as the rules the compiler and the validator enforce for you.

### Wave 2 — Caching (the differentiator) (6)

9. `caching/use-cache-directive` — file / component / function level; the async requirement; **what goes into a compiler-derived cache key** (build ID, serialized arguments, closure captures) and why that is the whole ballgame.
10. `caching/cache-lifetimes` — `cacheLife`; the three clocks (`stale` / `revalidate` / `expire`); preset and custom profiles; overriding `default`; nesting propagation and the deliberate prerender error; the thresholds at which a lifetime removes content from the prerender entirely. **Note from demo, resolved in session 7 §3:** the build table's route-level `Revalidate` / `Expire` columns track the **shortest lifetime among the `'use cache'` entries actually evaluated during that route's build-time prerender pass** — not the shortest entry on the page overall, and not the longest. An entry whose lifetime is too short to be safely prerendered drops out of that evaluation entirely (see the thresholds above), which is why the column can show a *longer* number while a shorter-lived panel still streams: the short one was excluded from the prerender pass, not merely absent from the visible shell. Confirmed by adding a second, shorter-lived cached call to `/streaming-coarse` (whose sole existing entry had separately been measured as absent from that route's rendered shell): the column moved from `1h 1d` to `1m 1h`, tracking the new shortest evaluated entry regardless of shell membership. Do not read these columns as "the lifetime of this page."
11. `caching/tags-and-invalidation` — `cacheTag`; `updateTag` (read-your-own-writes, Server Actions only) vs `revalidateTag(tag, profile)` (stale-while-revalidate, profile required) vs `revalidatePath`. Decision table.
12. `caching/private-and-remote-caches` — the three directives compared; `'use cache: remote'` (durable, network round-trip, platform fees) and `'use cache: private'` (**experimental**, browser-memory only, `connection()` prohibited). The cross-user leak as the motivating failure.
13. `caching/composition-and-cache-boundaries` — `children` and slots pass *through* a cached component without being cached; hoisting uncached work above a cached boundary; where the boundary should sit and why the instinct to put it at the page is usually wrong.
14. `caching/the-other-cache-layers` — request memoization, the client Router Cache, the `fetch` Data Cache, the Full Route Cache: which survived, which are now storage details, and how `'use cache'` layers on top.

### Wave 3 — Data and mutations (8)

15. `data/fetching-on-the-server` — the default path; sequential vs parallel; `Promise.all`; the preload pattern; where the waterfall actually comes from. Completes the RSC debt.
16. `data/runtime-data-and-cached-scopes` — read `cookies()` / `headers()` / `searchParams` *outside*, pass values as arguments. The single most-violated rule in the model, and the one with a security failure attached.
17. `data/route-handlers` — `GET` handlers now follow the page prerender model; the `'use cache'` helper indirection (the directive can't sit on the `GET` export); bail-out-by-throwing and what that does to your `try/catch`; when you don't need a route handler at all.
18. `mutations/server-functions` — `'use server'`; a Server Function is a public HTTP endpoint with a generated id; closure serialization and what leaks into it.
19. `mutations/forms-and-action-state` — `<form action>`, `useActionState`, `useOptimistic`, progressive enhancement, the pending-state contract. Cross-links to `reactjs-concepts/forms/forms-at-scale` for RHF + Zod at scale.
20. `mutations/validation-and-error-surfaces` — schema at the boundary; returning errors vs throwing; `redirect()` / `notFound()` inside an action.
21. `mutations/closing-the-loop` — the mutation succeeded and the UI didn't move. `cacheTag` on the read, `updateTag` on the write; why `router.refresh()` is the wrong reach.
22. `mutations/server-function-security` — actions are endpoints: authorize inside every one, never rely on the UI that called it; the still-callable-after-you-hid-the-button problem.

### Wave 4 — Routing and navigation (8)

23. `routing/route-groups-and-project-structure` — route groups `(marketing)`; private folders `_components`; colocation rules and why a stray `page.tsx` becomes a live URL; **multiple root layouts and the full-reload cost of crossing between them**; feature-folders vs type-folders at scale. Organization that is actually correctness.
24. `routing/layouts-templates-and-state` — what persists across navigation, what remounts, and why that changed. `template.tsx` as the deliberate remount.
25. `routing/dynamic-routes-and-params` — `params` is a promise; await it *inside* `<Suspense>` so the shell survives; `generateStaticParams` must return ≥1; `dynamicParams` is gone; `notFound()` as its replacement; the client hooks that suspend (`usePathname`, `useParams`, `useSelectedLayoutSegment(s)`, and `useSearchParams` always).
26. `routing/root-params` — `next/root-params` (16.3); i18n without prop-drilling; works inside `'use cache'` scopes; currently Server Components only.
27. `routing/parallel-and-intercepting-routes` — slots, `default.tsx`, the modal pattern, and the soft/hard navigation split that makes it work.
28. `routing/navigation-and-ui-state` — React `<Activity>` in `hidden` mode preserves `useState`, inputs, and scroll instead of unmounting. The three concrete regressions this creates and the reset patterns.
29. `routing/instant-navigation-and-prefetching` — Instant Insights; Partial Prefetching; per-link `prefetch` granularity; `export const instant = false`; prefetch inlining; the Router Cache's `stale` clock and its 30-second floor. **Opus tier.**
30. `routing/error-handling-and-recovery` — `error.tsx` and `not-found.tsx` vs `catchError` from `next/error` (16.3) with `retry()` that can re-render failed Server Components; why the old boundary interfered with `notFound` / `redirect`.

### Wave 5 — Production (14)

31. `auth/session-and-authorization` — where the session lives; the data-access-layer pattern; authorization as a check that runs outside every cached scope.
32. `auth/proxy-and-the-network-boundary` — `proxy.ts` (formerly `middleware.ts`); what belongs at the network boundary and what emphatically does not (authorization decisions).
33. `performance/the-client-bundle` — what actually ships; measuring it (Turbopack 16.3: sum `entryJSFiles` from `.next/server/app/<route>/page_client-reference-manifest.js` — there is no First Load JS column and no `app-build-manifest.json`); pushing `'use client'` to leaves; the shared-header de-opt; payload size vs bundle size.
34. `performance/images` — `next/image`; `remotePatterns`; `sizes` and the responsive contract; `priority` and LCP; `placeholder`; custom loaders; AVIF/WebP negotiation; the cost of self-hosting the optimizer.
35. `performance/fonts-and-cls` — `next/font`; subsetting; `font-display`; fallback metrics; CLS as the metric that makes fonts a different problem from images.
36. `performance/scripts-and-third-parties` — `next/script` loading strategies; `@next/third-parties`; measuring main-thread cost; CSP and nonce handling; where a script interacts with the static shell and hydration.
37. `seo/metadata` — `generateMetadata` / `generateViewport` under Cache Components; cache the external data, or accept a dynamic marker so the static content still prerenders.
38. `seo/sitemaps-robots-and-structured-data` — `sitemap.ts` including dynamic and segmented sitemaps; `robots.ts`; `opengraph-image` / `twitter-image` conventions; JSON-LD and where it goes under streaming; canonicals; `hreflang`.
39. `deployment/isr-with-cache-components` — prerender a subset with `generateStaticParams`; unprerendered URLs serve an instant shell on first visit then upgrade to fully prerendered in the background (16.3).
40. `deployment/self-hosting-adapters-and-cache-handlers` — Build Adapters API; `cacheHandlers`; immutable static assets across deploys; why `'use cache'` entries do not survive a deploy and `unstable_cache` entries did.
41. `deployment/observability-and-instrumentation` — `instrumentation.ts`, `after()`, OTel, what to measure once caching is explicit.
42. `ecosystem/testing` — Vitest + RTL for components; Playwright for flows; `instant()` from `@next/playwright` as a *regression gate on navigation speed*, which is a genuinely new category of test; testing Server Functions.
43. `ecosystem/build-pipeline` — Turbopack; filesystem cache for dev and build; memory eviction; TypeScript 7 via `useTypeScriptCli`; React Compiler including the experimental Rust-in-Turbopack path; `import.meta.glob`.
44. `ecosystem/data-layer` — where the DB call lives; connection pooling under serverless; why the ORM choice interacts with the cache boundary.

### Wave 6 — Migration (3) — the thesis, applied

45. `migration/fifteen-to-sixteen` — the mechanical upgrade; codemods (including the `./app` path trap); `instant = false` as the incremental lever; the synchronous-IO class of failure that no opt-out clears. Carries the expanded §9 translation table.
46. `migration/adopting-cache-components` — the route-at-a-time workflow driven by validation errors and insights; the `next-cache-components-adoption` skill and when to drive it manually instead.
47. `migration/pages-to-app` — `getServerSideProps` / `getStaticProps` / `getInitialProps` → Server Components + `'use cache'`. The only place Pages Router code appears.

**Scaffold changes required by this revision:** add `docs/concepts/seo/.gitkeep` and `docs/concepts/migration/.gitkeep`.

---

## 4. Recipe tracks — order

Symptom-first titles only. `caching/stale-dashboard-after-mutation`, never `caching/updateTag`. Tracks are named by domain and open in this order; a track opens once its gating concept article has landed.

1. **`caching/`** — opens first. The highest-value track and the one that pays the thesis.
2. **`rendering/`** — shell, streaming, hydration.
3. **`data-fetching/`** — waterfalls, duplicate queries, slow TTFB.
4. **`mutations/`** — actions that succeed and change nothing.
5. **`auth/`** — the leak class; flash of protected content.
6. **`routing/`** — preserved state, modals, back button.
7. **`performance/`** — bundle, LCP, prefetch cost, third-party scripts.
8. **`migration/`** — upgrade-day symptoms.
9. **`deployment/`** — self-hosted cache, cold starts.

---

## 5. Conventions

### Article template

Frontmatter: `article_id` (filename slug, **never numeric**), `concept_folder`, `wave`, `related`, `next_baseline`, `verified_against`, `verified_on`, `status`.

Sections, in order:

lead-with-this callout → what it is → how it works under the hood (traced to docs or source) → basic usage (complete, runnable) → **walkthrough** (end-to-end, full files) → **Then vs now** (mandatory) → real-world patterns → API / type reference table (when applicable) → common mistakes (7–10, with code) → exercises (2–3, with hints) → summary → see also (≥3) → references (official docs) → demo source

**Coverage bar, not line quota.** Length is a smell test for missing coverage, never the goal. The walkthrough is the single highest-leverage section and is never optional.

### The "Then vs now" section — mandatory

Four columns. The fourth is load-bearing:

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |

*"`revalidate` was renamed to `cacheLife`"* is a **rejected** answer. The accepted answer explains that the route-segment config was a whole-route declaration resolved at build planning time, whereas `cacheLife` attaches a profile to an individual cache entry whose key the compiler derives from the function's inputs — which is why one route can now hold many entries with different lifetimes.

Every such section cites ≥1 row of [`docs/evolution-ledger.md`](docs/evolution-ledger.md), **or** states explicitly: `No mechanism change — this surface is stable since vN`. Neither present → the article fails review.

### Legacy surfaces

Dead APIs (ledger Ban=`yes`) appear only in one of three forms:

1. A section whose nearest heading matches
   `/then vs now|how this evolved|migration|common mistakes/i`
2. A fenced block whose first content line (or the line before the opening
   fence) is exactly:

```tsx
// legacy: Next <16 implicit-caching model — see docs/evolution-ledger.md
```

3. A `legacy-ok` region, for tables or inline prose that must name a dead
   surface outside those sections. `reason=` is required and non-empty;
   unclosed or nested regions fail:

```markdown
<!-- legacy-ok:start reason=historical description of the pre-16 four-layer cache model -->
…content…
<!-- legacy-ok:end -->
```

`scripts/verify-legacy-markers.mjs` reads Ban=`yes` tokens from the ledger and
fails CI on any live use. Its summary reports region counts; `--verbose` lists
each `file:line — reason`.

### The extraction pipeline

Articles are authored as `.md.tpl` with `{EXTRACT:}` tokens and delivered alongside their demo sources. The `.md` is a build artifact and is never edited by hand. **`.tpl`-native is the standard from article 5 onward** (and for 3, 4, 7, 8+). Articles 1 and 2 remain conversion debt: 1 should be cheap (demos exist); 2 is blocked on a real payload measurement across the stage-2 boundary before convert. The `unsourced-other` count in `verify-code-blocks` should fall toward zero and never grow.

Prose is authored in `<article>.md.tpl`. **Code never is.** Templates carry `{EXTRACT:<path>#<symbol>}` tokens; `scripts/build-article.py` resolves them into a provenance comment plus a fenced block; `scripts/verify-code-blocks.mjs` re-extracts and compares. Extraction logic lives in exactly one place — `scripts/lib/extract.mjs` — so the builder and verifier cannot disagree. Symbol extracts include the import statements the region actually uses; `#<symbol>-imports` opts out for deliberate fragments.

**A template ships in `prompts/<session>/`, not `docs/`, until its demos exist.** `verify:templates` (`build-article.py --check --all`) only scans `.md.tpl` files under `docs/`, so a template whose `{EXTRACT:}` tokens point at demo files a session hasn't written yet breaks the gate for everyone the moment it lands — that happened with article 8's template. The session that authors the template keeps it in `prompts/<session>/` alongside its own prompt, writes the demos, and **moves** the template into its final `docs/concepts/<folder>/` location as the session's last step, once every extract target resolves. An in-flight template never breaks the chain because the gate never sees it.

**Demo sources are article content** — written for extraction, not trimmed afterward. **Observations are batched**: when an article needs recorded output, the demo delivery names every capture command up front so they run in one pass.

Policy: **`status: draft` articles may carry authored code blocks; anything past draft may not.** CI runs `verify-code-blocks --strict`. Unsourced `bash`/`sh`/`shell` fences are the documented exception (shell commands have no demo source); the summary line reports their count.

Gate order: `build-article --check --all` → `verify-code-blocks --strict` → `verify-links` → `verify-legacy` → demo build → demo test. `--check` runs first because a drifted template makes every later gate report on a stale artifact.

### Code conventions

- App Router, TypeScript strict, no `any`. Typed route helpers (`PageProps<'/blog/[slug]'>`) over hand-written prop types.
- Server-first: a component is a Server Component until it has a reason not to be. `'use client'` is pushed to leaves and the reason is stated in a comment.
- **Runtime data is read outside cached scopes and passed in as arguments.** Any deviation is called out as the exception it is.
- Every Server Function authorizes independently. No example relies on the caller's UI as the authorization.
- `await params` / `await searchParams` happens inside a `<Suspense>`-wrapped child, not at the top of a page.
- `cacheLife` is called in every `'use cache'` scope.
- `'use cache: private'` carries an experimental marker at every appearance.
- Named exports; colocated tests; no barrel files.

### Measurement standard

- Every performance figure is reproduced in `demos/next-lab` with the method stated inline (cold vs warm build separated; production build, never `next dev`; median of N runs; ratios alongside absolute times).
- A figure that cannot be reproduced is replaced with a range, or removed.
- **Vendor benchmarks are cited as theirs, never restated as ours.** Vercel's "5.5× faster builds" and "22% more requests under load" are attributed claims about their apps.
- Caching claims are verified with `next build && next start`, because caching behavior differs in dev.
- **Shell claims are verified against `.next/server/app/<route>.html`, never against a response body.** A streamed response contains both the fallback and the resolved content, so `curl`, view-source, and DevTools all show a completed stream rather than the shell. The build artifact is the only place the shell exists in isolation.
- A `◐` annotation reports that a route produced a shell, not that the shell contains anything useful. Shell *quality* claims require reading the artifact.
- TTFB and total load time often cannot distinguish fine-grained from coarse boundaries when both flush a shell immediately and both finish on the slowest child — measure time-to-first-panel / stream `$RC` count, or read the HTML.
- Client-bundle size for a route (Turbopack / Next 16.3): sum the byte sizes of the files listed under `entryJSFiles` for that page in `.next/server/app/<route>/page_client-reference-manifest.js`. There is no First Load JS column in the build table, and `app-build-manifest.json` is not emitted. Prefer `@next/bundle-analyzer` when the question is *which module* rather than *how much*.
- Validation **diagnostics never appear in the HTTP response** — a blocked route still returns `200` in `next dev`. Reading them requires the dev overlay, the dev-server log, or the DevTools MCP. **The same diagnostic may be fatal at `next build`**, so a passing `next dev` is not evidence of either correctness or buildability.

### Cross-referencing

- "See also" lists ≥3 items. Composition is content: articles that compose reference each other in the walkthrough, not only at the end.
- Sideways links into `reactjs-concepts` for React primitives rather than re-teaching them.
- Inline links carry real anchors, **verified against files on disk**. Guessed slugs are a known repeat failure in this suite.

---

## 6. Phase structure

- **Phase 1a — The model + caching.** Waves 1–2 (14 articles), in order. Approval checkpoint after the first 3, then rolling delivery. This is the differentiator; it ships first.
- **Phase 1b — Recipes.** Opens once Wave 1 lands; runs in parallel thereafter. Tracks in §4 order.
- **Phase 1c — Data, routing, production.** Waves 3–5, interleaved with recipes.
- **Phase 2 — Migration.** Wave 6. Deliberately last: the migration articles are the thesis *applied*, and they read better once the reader has the whole new model.

Working directory: `E:\linh tinh\EverythingFromDayOne\experimental-projects\nextjs-concepts\`. Cursor handles bulk file operations and extraction; Claude generates content; fresh chat per session with state carried in `progress.md`.

---

## 7. Invented decisions — flagged for approval

1. **`partialPrefetching: true` from day one.** Opt-in in 16.3, but stated to become default in a future major. Teaching the opt-out state would date the repo within one release.
2. **Drizzle + PostgreSQL 18 for demos.** `nestjs-concepts` uses TypeORM then Prisma; a third ORM keeps the repos from implying a stack endorsement, and Drizzle's serverless story is the common 2026 Next pairing. *Alternative: Prisma, for continuity.*
3. **`verified_against` / `verified_on` frontmatter stamps.** New to this suite; justified by release cadence.
4. **47 articles across 6 waves**, with Wave 6 (migration) last rather than first. Mitigated by making it the first entry in README's "Where to start".
5. **Cross-repo links warn rather than fail** in `verify-links.mjs` when the sibling repo isn't on disk.
6. **`'use cache: private'` demoted to escape-hatch status** rather than taught as a peer of the other two directives, since it is experimental and depends on runtime prefetching, which is not yet stable.
7. **Wave 2 front-loaded ahead of data and routing.** Conventional ordering teaches routing before caching; the thesis argues the opposite.
8. **`ecosystem/testing` includes navigation-speed regression tests** as a first-class category, which no other repo in the suite has.
9. **`rendering/client-side-rendering` at position 7, inside Wave 1.** It lengthens the wave before caching — but a four-answer model with an unowned answer is worse than a longer wave. *(new in rev 2)*
10. **New `seo/` concept folder**, with `metadata` moved into it from `routing/`. Readers look for `generateMetadata` under SEO, not routing. Cheap now; nothing links to it yet. *(new in rev 2)*
11. **Images and fonts split into two articles.** Reversible; recombining later is easy, splitting a written article later is not. *(new in rev 2)*
12. **No `rendering-strategies-overview` article**, despite every comparable resource having one. The CSR/SSR/SSG/ISR taxonomy is the artifact this repo argues against; covering it as a learning path would reproduce the confusion. Handled by the §9 translation table instead. **The most contestable decision here.** *(new in rev 2)*
13. **Wave 5 kept at 14 articles** rather than split into 5a (auth / performance / seo) and 5b (deployment / ecosystem). *(new in rev 2)*
14. **The extraction pipeline design** — a single shared extractor with Python shelling out to Node, the `<!-- extract: … -->` provenance format, `.md.tpl` as the template extension, and the draft-vs-complete strictness policy. *(new in rev 2)*

---

## 8. First deliverables

### First 3 concept articles — 🟢 all drafted

Delivery order deviates from reading order once: article 6 shipped third, because it is the thesis anchor that every later "Then vs now" cites.

1. **`foundations/thinking-in-the-app-router`** 🟢 — the mental-model anchor. Build → shell → stream, as one picture.
2. **`foundations/server-and-client-components`** 🟢 — the boundary as a module-graph and network boundary. Pays the RSC debt.
3. **`caching/cache-components-model`** 🟢 — the inversion and the four-way decision. Locks the "Then vs now" convention by example.

All three carry authored (not yet extracted) code blocks and a **Verification status** block listing what still needs demo confirmation. **The next action on these is not a fourth article** — it is running one of them through the full extraction pipeline against real demo routes, so the gates are proven before 44 more articles depend on them.

### First 3 recipes

1. **`caching/everything-went-dynamic-after-the-upgrade`** — upgraded to 16; a page that was static now renders per request; TTFB and infrastructure cost both jump. Fix arc: read the validation insights rather than guessing → `'use cache'` at the right granularity (not at the page) → `cacheLife` → measure with `next build && next start`.
2. **`caching/user-a-sees-user-b-data`** — symptom: `data-uid` for alice returned under bob's cookie. Escaped QA because one user in dev, and the `cookies()`-inside-cache guard made the whole class look covered. Fix arc: the key holds arguments, not the request → show the caught form (runtime throw, not build) → show the two uncaught forms (module capture; coarse key) → **the argument must identify the data** → authorization outside every cached scope → when NOT to use `'use cache: private'`. Demo: `lib/billing-leak-{a,b,c}.ts` + `app/leak-{a,b,c}/` (retain all six). **The scariest recipe in the repo.**
3. **`mutations/action-succeeded-ui-didnt-update`** — the write lands and the page still shows the old value. Fix arc: `cacheTag` on the read → `updateTag` vs `revalidateTag(tag, profile)` → why `router.refresh()` is the wrong reach → the decision table.

---

## 9. Translation table — for readers arriving with the four-strategies model

Goes in `README.md`; expanded inside article 45.

| What you were taught | What it is now | Articles |
| --- | --- | --- |
| **SSG** — the page is static | The whole route produced a shell and nothing aborted the prerender | 1, 5 |
| **SSR** — the page is dynamic | At least one boundary contains a runtime read; everything else still prerenders | 1, 5, 16 |
| **ISR** — static, regenerated on a timer | `cacheLife`'s `revalidate` clock, plus shell-then-upgrade for unprerendered params | 10, 39 |
| **CSR** — render in the browser | One of four answers, chosen per boundary rather than per app | 7 |
| **"Is this route static or dynamic?"** | Wrong question. Ask it per boundary. | 1 |
| **Request Memoization** | Still there, still automatic, still per-request | 14 |
| **Data Cache** | A storage layer beneath `'use cache'`; no longer an author-facing decision | 9, 14 |
| **Full Route Cache** | Replaced by the static shell plus per-scope cache entries | 6, 14 |
| **Router Cache** | Alive and now central — `cacheLife`'s `stale` clock drives it, with a 30-second floor so prefetches stay usable | 14, 29 |
| **`export const dynamic`** | Deleted. A build error, not a no-op. | 6 |
| **`export const revalidate`** | `cacheLife(profile)` inside the cached scope | 6, 10 |
| **`unstable_cache`** | `'use cache'`, with compiler-derived keys | 9 |
| **`loading.tsx` as the only loading state** | Any `<Suspense>` boundary; shells extracted from any route | 5, 29 |

---

## Approval checklist

### Baseline (§1)
- [ ] Next 16.3.0 / Node 22 / Turbopack / `cacheComponents` on
- [ ] React 19.2 recorded as a **repo stance**, not a framework floor
- [ ] **TypeScript decision resolved** — bump to `^7` attempted, outcome recorded either way
- [ ] `partialPrefetching: true` from day one *(§7.1)*
- [ ] Drizzle + PostgreSQL for demos *(§7.2)*
- [ ] `verified_against` / `verified_on` stamps *(§7.3)*

### Stance (§2)
- [ ] Thesis framing — the stale-answer tax
- [ ] App-Router-only, Cache-Components-from-day-one, `'use cache: private'` demoted *(§7.6)*
- [ ] This repo pays `reactjs-concepts`' RSC debt

### Structure (§3–§4)
- [ ] 47 articles, wave assignment, and count *(§7.4, §7.7, §7.13)*
- [ ] `rendering/client-side-rendering` at position 7 *(§7.9)*
- [ ] New `seo/` folder; `metadata` moved out of `routing/` *(§7.10)*
- [ ] Images and fonts split *(§7.11)*
- [ ] **No `rendering-strategies-overview` article** *(§7.12 — the contestable one)*
- [ ] Recipe track order

### Conventions (§5)
- [ ] Mandatory "Then vs now" four-column shape
- [ ] Extraction pipeline and draft-vs-complete strictness *(§7.14)*
- [ ] Measurement standard, including vendor-benchmark attribution and the insights-aren't-in-the-response caveat

### Delivery (§6, §8, §9)
- [ ] Phase structure, migration last
- [ ] First three articles accepted as drafts; **pipeline proof-out before article 4**
- [ ] Translation table placed in README and article 45

On approval: run one delivered article through the extraction pipeline end to end, then continue with article 5 or recipe 1.