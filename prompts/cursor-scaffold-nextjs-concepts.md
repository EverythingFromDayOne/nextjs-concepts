# Cursor prompt — scaffold `nextjs-concepts` (structure only, zero article prose)

Paste everything below the line into Cursor. It is a **scaffolding-only** task: create the skeleton, the templates, the verification gates, and the seed ledgers. **Do not write any article or recipe body content.** Content generation happens in Claude sessions afterwards.

---

## 0. Role and hard constraints

You are scaffolding a new standalone technical learning repository, `nextjs-concepts`, in:

```
E:\linh tinh\EverythingFromDayOne\experimental-projects\nextjs-concepts\
```

It is the fifth in a suite (`angular-concepts`, `reactjs-concepts`, `nestjs-concepts`, `dsa-concepts`). It follows the same architecture: concept articles + symptom-first debugging recipes, verbatim-extracted code blocks from a tested demo app, CI gates, and a locked editorial template.

**Hard constraints for this task:**

1. **Structure only.** Create directories, templates, config, scripts, CI, and planning documents with explicit `TODO` markers. Write **no** concept-article prose, **no** recipe prose, **no** worked examples beyond what a template needs to demonstrate its own shape.
2. **Do not trust your training data about Next.js.** See §1. This is non-negotiable and is the single most likely way this task goes wrong.
3. **Surface every invented decision.** Anything you inferred, guessed, or chose without being told — list it explicitly in your final report under `INVENTED DECISIONS`. Silent assumption is a failure, even when the assumption turns out correct.
4. **Do not `npm install` into the docs root.** The demo app is a separate workspace package (§5).

---

## 1. Pre-flight — verify the baseline before you write a single file

Your training data almost certainly predates the current Next.js. The framework inverted its caching defaults in v16; code that was correct in 14/15 is now *wrong*, not merely dated. Next.js ships an explicit warning about exactly this problem.

Run these first, and record the real output:

```bash
npm view next version
npm view next dist-tags --json
npm view react version
npm view typescript version
node --version
pnpm --version
```

Then, after the demo app exists (§5), **read the bundled docs** rather than recalling them:

```
demos/next-lab/node_modules/next/dist/docs/
```

Next.js 16.2+ bundles its own documentation into `node_modules` and points `AGENTS.md` at it precisely because agents write stale Next.js code. Treat that directory as the authority for every claim in this repo.

**Write the verified numbers into `roadmap.md` §1 as the locked baseline.** If any observed version differs from the assumptions below, use the observed one and flag the delta in your report.

**Assumed-at-authoring baseline (verify, do not copy blindly):**

| Thing | Assumed | Verify how |
| --- | --- | --- |
| Next.js | 16.3.x stable | `npm view next version` |
| React / React DOM | whatever `create-next-app` pins | read generated `package.json` |
| TypeScript | 7.x (10× native port; supported for `next build` type-checking as of 16.3) | `npm view typescript version` |
| Node | 24 LTS | `node --version` |
| Bundler | Turbopack, default for dev **and** build; build filesystem cache on by default in 16.3 | `next build` output |
| Package manager | pnpm workspaces | — |
| Router | App Router only. Pages Router appears **only** as migration material. | — |
| Caching | `cacheComponents: true` **on** from day one | `next.config.ts` |

---

## 2. The repo's thesis — lock this before structuring anything

Every repo in this suite has one differentiating thesis. `dsa-concepts` has the **JS tax**. This one has:

> **The stale-answer tax.** Almost every Next.js tutorial, StackOverflow answer, blog post, and LLM completion in existence was written against Next 13–15, where the framework cached aggressively by default and you opted *out*. Next 16 inverted that: everything is dynamic by default and you opt *in* with `'use cache'`. The same code, unchanged, now means the opposite thing. Advice that was correct two years ago is not merely outdated — it silently produces wrong caching behavior, and the failure is invisible in `next dev`.

**Consequence for the editorial template: the "Then vs now" section is MANDATORY on every article, not optional.** This is the extension of the version-evolution convention already locked in `angular-concepts` (old-vs-new must explain the *underlying machinery*, never just the API rename).

The required shape, per article:

| Aspect | Next 13–15 (implicit caching) | Next 16+ (Cache Components) | What actually changed underneath |
| --- | --- | --- | --- |
| … | … | … | *mechanism*, not API name |

The fourth column is the load-bearing one. "`revalidate` was renamed to `cacheLife`" is a **rejected** answer. The accepted answer explains that the route-segment config was a whole-route declaration evaluated at build planning time, whereas `cacheLife` is a per-cache-scope profile attached to an individual cache entry whose key the compiler derives from the function's inputs — which is why one route can now hold many cache entries with different lifetimes.

---

## 3. Directory tree to create

Create exactly this. Every leaf directory gets a `.gitkeep`. Every `.md` listed gets a stub with frontmatter + `TODO` markers only.

```
nextjs-concepts/
├─ README.md
├─ roadmap.md
├─ progress.md
├─ LICENSE                        # MIT, matching the suite
├─ CREDITS.md
├─ AGENTS.md                      # agent-facing rules; see §6
├─ .gitignore
├─ .editorconfig
├─ package.json                   # root, pnpm workspace
├─ pnpm-workspace.yaml
├─ docs/
│  ├─ evolution-ledger.md         # THE anchor document — see §4
│  ├─ templates/
│  │  ├─ ARTICLE_TEMPLATE.md
│  │  └─ RECIPE_TEMPLATE.md
│  ├─ concepts/
│  │  ├─ foundations/.gitkeep
│  │  ├─ rendering/.gitkeep
│  │  ├─ caching/.gitkeep
│  │  ├─ routing/.gitkeep
│  │  ├─ data/.gitkeep
│  │  ├─ mutations/.gitkeep
│  │  ├─ auth/.gitkeep
│  │  ├─ performance/.gitkeep
│  │  ├─ deployment/.gitkeep
│  │  └─ ecosystem/.gitkeep
│  └─ recipes/
│     ├─ index.md                 # stub table, header row only
│     ├─ caching/.gitkeep
│     ├─ rendering/.gitkeep
│     ├─ data-fetching/.gitkeep
│     ├─ routing/.gitkeep
│     ├─ mutations/.gitkeep
│     ├─ auth/.gitkeep
│     ├─ performance/.gitkeep
│     ├─ migration/.gitkeep
│     └─ deployment/.gitkeep
├─ demos/
│  └─ next-lab/                   # see §5
├─ scripts/
│  ├─ verify-code-blocks.mjs
│  ├─ verify-links.mjs
│  ├─ verify-legacy-markers.mjs   # NEW gate — see §7
│  └─ build-article.py            # template + {PLACEHOLDER} builder
└─ .github/
   └─ workflows/
      └─ verify.yml
```

**Port, don't rewrite:** `verify-code-blocks.mjs` and `verify-links.mjs` already exist in the sibling repos. Check `../reactjs-concepts/scripts/` and `../dsa-concepts/scripts/` in that order and copy the newer implementation verbatim, preserving its CLI contract (exit non-zero on failure, print file:line). Same for `build-article.py`. If neither sibling is present on disk, create stubs that fail loudly with `NOT PORTED — copy from a sibling repo` rather than inventing a second implementation that will drift.

---

## 4. `docs/evolution-ledger.md` — the anchor document

This is the single most important file you create. It is the repo's spine: a running table of every place Next.js changed mechanism, which every article links back to and which the CI legacy-marker gate reads its banned-token list from.

Create it with the table below **seeded from the migration guide**, each row marked `⚪ unwritten` in a Status column. Do not add rows you can't cite — leave the "Cite" column as `TODO: verify` rather than guessing a doc URL.

| Old surface | New surface | Kind of change | Owning article (planned) |
| --- | --- | --- | --- |
| `export const dynamic = 'force-dynamic'` | *deleted* — everything is dynamic by default | default inversion | `caching/cache-components-model` |
| `export const dynamic = 'force-static'` | `'use cache'` + `cacheLife('max')` | opt-out → opt-in | `caching/use-cache-directive` |
| `export const revalidate = N` | `cacheLife(profile)` | route-scope → cache-entry-scope | `caching/cache-lifetimes` |
| `export const fetchCache` | *deleted* — fetches inside a `'use cache'` scope are cached | scope inheritance | `caching/use-cache-directive` |
| `fetch(url, { cache, next: { revalidate, tags } })` | wrap the fetch in `'use cache'` + `cacheLife` + `cacheTag` | per-call → per-scope | `data/fetching-on-the-server` |
| `unstable_cache(fn, keyParts, opts)` | `'use cache'` — compiler derives the key from arguments | manual key → compiler-derived key | `caching/use-cache-directive` |
| `unstable_noStore()` / `noStore()` | *deleted* — nothing is cached unless you say so; use `connection()` + `<Suspense>` when work must run per-request | default inversion | `rendering/dynamic-and-connection` |
| `cookies()` / `headers()` / `searchParams` opting the whole route dynamic | same APIs, but must sit inside `<Suspense>`; the rest of the page still prerenders | route-level → boundary-level | `rendering/static-shell-and-streaming` |
| `experimental.ppr` / `export const experimental_ppr` | removed — PPR is folded into `cacheComponents` | experimental → default architecture | `rendering/partial-prerendering` |
| `experimental.dynamicIO` / `experimental.useCache` | `cacheComponents: true` | flag rename + stabilization | `caching/cache-components-model` |
| `revalidateTag(tag)` | `revalidateTag(tag, profile)` (profile now **required**); `updateTag(tag)` for read-your-own-writes from a Server Action | SWR vs. immediate split | `mutations/invalidation` |
| `dynamicParams` | unsupported under Cache Components — `notFound()` instead | removed config | `routing/dynamic-routes-and-params` |
| `generateStaticParams()` returning `[]` | must return ≥1 param so a shell can be validated | contract tightened | `routing/dynamic-routes-and-params` |
| `const { slug } = await params` at the top of a page | pass the promise into a `<Suspense>`-wrapped child and await it there | blocking → shell-preserving | `routing/dynamic-routes-and-params` |
| `middleware.ts` | `proxy.ts` | renamed to clarify the network boundary | `auth/proxy-and-the-network-boundary` |
| `export const runtime = 'edge'` | deprecated; Node.js runtime required for Cache Components | runtime narrowing | `deployment/runtimes` |
| unmount-on-navigate | React `<Activity>` in `hidden` mode preserves `useState`, inputs, scroll | lifecycle change with real bug surface | `routing/navigation-and-ui-state` |
| eager prefetch of every viewport link | Partial Prefetching — one reusable shell per route | network-shape change | `performance/prefetching` |
| Webpack | Turbopack default (dev + build), disk cache on by default | toolchain replacement | `ecosystem/build-pipeline` |
| `getServerSideProps` / `getStaticProps` / `getInitialProps` | Server Components + `'use cache'` | paradigm replacement | `migration/pages-to-app` |
| *(new, no predecessor)* | `export const instant = false` | new opt-out from instant-navigation validation | `rendering/instant-navigation-validation` |
| *(new, no predecessor)* | `'use cache: remote'` / cache handlers | durability across instances & deploys | `deployment/cache-handlers` |

Add a header note to the file:

> Every article's **Then vs now** section must cite at least one row here, or explicitly state `No mechanism change — this surface is stable since vN`. An article with neither fails review.

---

## 5. `demos/next-lab` — the code-block source of truth

Articles never contain hand-typed code. Code blocks are **extracted verbatim** from a demo app that actually builds and passes tests. Scaffold it:

```bash
cd demos
pnpm create next-app@latest next-lab --typescript --app --eslint --no-src-dir --use-pnpm
```

Then:

1. Set `cacheComponents: true` in `demos/next-lab/next.config.ts`.
2. Record the exact `create-next-app` version and the generated dependency versions into `roadmap.md` §1.
3. Add a `demos/next-lab/routes/` convention note: each article gets a route segment named for its slug, so extraction is mechanical.
4. Add `pnpm build` and `pnpm test` scripts wired into CI.
5. **Do not** build any feature routes. One placeholder route proving `cacheComponents: true` compiles is the whole deliverable here.
6. Note in `progress.md` whether `create-next-app` offered any prompt you had to answer, and what you chose.

Also register the Next.js DevTools MCP server in the repo's Cursor config if the mechanism exists at the version you install — it is how validation insights get read programmatically. If you cannot verify it, leave a `TODO` rather than writing a config you haven't confirmed.

---

## 6. `AGENTS.md`

Short and blunt. It exists so that future agent sessions on this repo do not regress to Next 15 idioms:

- This repo targets Next.js `<verified version>`. Your training data is older than that and the caching defaults **inverted**.
- Before writing any Next.js code or claim, read `demos/next-lab/node_modules/next/dist/docs/`.
- Never write `export const dynamic`, `unstable_cache`, `noStore()`, `experimental_ppr`, `fetchCache`, or `middleware.ts` as live guidance. They appear **only** inside a `Then vs now` section or a fenced block carrying the legacy marker.
- Legacy marker comment, exact form:
  ```tsx
  // legacy: Next <16 implicit-caching model — see docs/evolution-ledger.md
  ```
- Every claim traced to official docs or framework source before it is written; hedge explicitly when it can't be verified in-session.

---

## 7. `scripts/verify-legacy-markers.mjs` — the new third gate

This mechanizes §2. Behavior:

1. Read the banned-token list from the "Old surface" column of `docs/evolution-ledger.md` (parse the table; do not hardcode a second copy).
2. Walk every `.md` under `docs/`.
3. For each banned token occurrence, **pass** only if it is inside a section whose nearest preceding heading matches `/then vs now|how this evolved|migration/i`, **or** inside a fenced code block whose preceding line carries the legacy marker comment.
4. Otherwise **fail** with `file:line — banned legacy surface 'X' outside a Then-vs-now section or legacy-marked block`.
5. Exit non-zero on any failure. Print a summary count.

Wire all three gates into `.github/workflows/verify.yml`, plus the demo build and test:

```
verify:code-blocks  →  verify:links  →  verify:legacy  →  demo build  →  demo test
```

All must pass before an article is considered complete.

---

## 8. Templates

### `ARTICLE_TEMPLATE.md`

Frontmatter: `article_id` (filename slug, **not** numeric), `concept_folder`, `wave`, `related`, `next_baseline`, `react_baseline`, `status`.

Sections, in order — `{PLACEHOLDER}` tokens, no prose:

1. Lead-with-this callout
2. What it is
3. How it works under the hood — real internals, traced to docs or source
4. Basic usage — complete, runnable
5. Walkthrough — one thing built end-to-end, full files *(highest-leverage section; never optional)*
6. **Then vs now** — the four-column table from §2, plus ≥1 evolution-ledger link *(MANDATORY)*
7. Real-world patterns
8. API / type reference table (when applicable)
9. Common mistakes — 7–10, each with code
10. Exercises — 2–3, with hints
11. Summary
12. See also (≥3)
13. References — official docs only
14. Demo source — path into `demos/next-lab/`

Add the standing note: **coverage bar, not line quota.** Length is a smell test for missing coverage, never the goal.

### `RECIPE_TEMPLATE.md`

Frontmatter: `recipe_id`, `primary_concept`, `difficulty` (`foundational` | `intermediate` | `advanced`), `next_baseline`.

Sections: What you'll build → the scenario (concrete failure mode, with numbers) → why it escaped QA → walkthrough (staged) → variations → trade-offs and pitfalls, 10–15, including a real **when NOT to use this** → verify-the-loop → see also (≥3) → references → demo source.

Symptom-first titles only. `caching/stale-dashboard-after-mutation`, not `caching/updateTag`.

---

## 9. Planning documents — skeletons only

- **`roadmap.md`** — §1 locked baseline (from your verified numbers), §2 stance (App Router only; `cacheComponents: true` from day one; Pages Router is migration material), §3 article waves *(headers + empty tables; Claude fills the article list)*, §4 recipe track order *(headers only)*, §5 conventions, §6 phase structure, §7 first deliverables *(empty)*, plus an **approval checklist** at the bottom with every section unchecked.
- **`progress.md`** — legend (✅ 🟢 🟡 ⚪ ❌), empty wave tables matching `roadmap.md` §3, an `Open questions / TODOs` list, and a `Session log` section with your scaffolding session as entry one.
- **`README.md`** — reader-facing: what the repo is, the stale-answer-tax thesis in two sentences, the target layout tree marked *"target layout — see `progress.md` for what has landed"*, and a `Where to start` block.

---

## 10. What NOT to do

- Do not write article or recipe bodies. Stubs and templates only.
- Do not invent a Next.js API you have not read in the bundled docs.
- Do not copy code idioms from your training data. If a snippet feels familiar, that is evidence it is Next 15.
- Do not fill in the roadmap's article list — that is a Claude decision in the next session.
- Do not reimplement the verify scripts if a sibling repo has them.
- Do not create `docs/getting-started.md` or similar unlisted files.

---

## 11. Acceptance checklist — verify before reporting

- [ ] `pnpm install` at root succeeds; workspace resolves `demos/next-lab`
- [ ] `pnpm --filter next-lab build` succeeds with `cacheComponents: true`
- [ ] `node scripts/verify-links.mjs` runs and exits 0 on the stub tree
- [ ] `node scripts/verify-legacy-markers.mjs` runs, parses the ledger table, and exits 0
- [ ] `node scripts/verify-legacy-markers.mjs` exits **non-zero** when you temporarily add `export const dynamic = 'force-dynamic'` to a scratch `.md` outside a Then-vs-now section *(prove the gate actually fires, then delete the scratch file)*
- [ ] Every directory in §3 exists; every leaf has `.gitkeep`
- [ ] `docs/evolution-ledger.md` has every §4 row with a Status column
- [ ] `git init` done, initial commit made, nothing in `.gitignore` is tracked

---

## 12. Final report format

End with exactly these four blocks:

```
OWNED        — what was created, file counts, verified version numbers (actual, not assumed)
DEBT PAID    — n/a for scaffolding, or anything ported from siblings
INVENTED     — every decision you made that wasn't specified here, one line each
NEXT         — what the following Claude session should start with
```

Under `INVENTED`, be exhaustive. Choosing a concept-folder name, an ESLint config, a `.gitignore` line, a script's exit-code convention, a `create-next-app` prompt answer — all of it goes in the list. An empty `INVENTED` block on a scaffolding task is not credible and will be treated as a failure to report.
