# `nextjs-concepts` — roadmap

The stable plan. Day-to-day state lives in `progress.md`.

---

## 1. Locked baseline (verified 2026-08-10)

| Surface | Locked value | How verified | Delta vs assumed-at-authoring |
| --- | --- | --- | --- |
| Next.js | `16.3.0` (`latest`) | `npm view next version` → `16.3.0`; `create-next-app@16.3.0` generated `next@16.3.0` | Assumed `16.3.x` — match |
| React / React DOM | `19.2.8` | `demos/next-lab/package.json` from `create-next-app` | Assumed "whatever create-next-app pins" — match |
| TypeScript (demo pin) | `^5` → resolved `5.9.3` | `demos/next-lab/package.json` + installed `node_modules/typescript` | Assumed `7.x` from `npm view typescript version` (= `7.0.2`) — **delta**: `create-next-app` still pins `typescript@^5` |
| TypeScript (registry latest) | `7.0.2` | `npm view typescript version` | Recorded for awareness; demo stays on create-next-app pin until verified safe to bump |
| Node | `v22.22.0` (this machine) | `node --version` | Assumed **24 LTS** — **delta**: scaffold host is Node 22; engines set to `>=22` |
| pnpm | `10.33.0` | `pnpm --version` | — |
| Bundler | Turbopack (dev + build) | `pnpm --filter next-lab build` → `Next.js 16.3.0 (Turbopack)` + `Cache Components enabled` | Assumed Turbopack — match. Disk-cache wording not separately printed in this build log — leave as observed Turbopack default |
| Package manager | pnpm workspaces | `pnpm-workspace.yaml` → `demos/*` | — |
| Router | App Router only | `create-next-app --app` | Pages Router = migration material only |
| Caching | `cacheComponents: true` | `demos/next-lab/next.config.ts` | On from day one |
| create-next-app | `16.3.0` | `npm view create-next-app version` | Template: `app-tw` (App Router + Tailwind) |

**Next.js dist-tags at verification** (`npm view next dist-tags --json`):
`latest=16.3.0`, `canary=16.3.1-canary.9`, `preview=16.3.0-preview.10`,
`backport=15.5.23`.

---

## 2. Stance

- **App Router only.** Pages Router appears only as migration material
  (`migration/pages-to-app` and related recipes).
- **`cacheComponents: true` from day one.** No dual-mode corpus. The stale-answer
  tax is the thesis; teaching the old defaults as current is out of scope.
- **Code is extracted, never invented.** Every fenced sample comes from
  `demos/next-lab/` after `pnpm --filter next-lab build` (and tests) pass.
- **Then vs now is mandatory** on every concept article (mechanism column required).
- **Bundled docs are authority.** `demos/next-lab/node_modules/next/dist/docs/`.

---

## 3. Article waves

Headers + empty tables only. Article lists are filled in a later Claude session.

### Wave 0 — foundations

| # | Slug | Owns |
| --- | --- | --- |
| | | |

### Wave 1 — rendering + caching spine

| # | Slug | Owns |
| --- | --- | --- |
| | | |

### Wave 2 — routing + data + mutations

| # | Slug | Owns |
| --- | --- | --- |
| | | |

### Wave 3 — auth + performance + deployment

| # | Slug | Owns |
| --- | --- | --- |
| | | |

### Wave 4 — ecosystem + migration

| # | Slug | Owns |
| --- | --- | --- |
| | | |

<!-- TODO: Claude fills the article inventory. Do not invent slugs here beyond evolution-ledger planned owners. -->

---

## 4. Recipe track order

Headers only. Symptom-first titles; fill later.

### Track A — caching failures

<!-- TODO -->

### Track B — rendering / streaming failures

<!-- TODO -->

### Track C — data-fetching failures

<!-- TODO -->

### Track D — routing failures

<!-- TODO -->

### Track E — mutation / invalidation failures

<!-- TODO -->

### Track F — auth / network-boundary failures

<!-- TODO -->

### Track G — performance failures

<!-- TODO -->

### Track H — migration failures

<!-- TODO -->

### Track I — deployment failures

<!-- TODO -->

---

## 5. Conventions

| Convention | Rule |
| --- | --- |
| Article IDs | Filename slug, **not** numeric |
| Folders | `docs/concepts/<area>/`, `docs/recipes/<area>/` |
| Demo routes | `demos/next-lab/` segment named for article/recipe slug — see `demos/next-lab/routes/README.md` |
| Legacy surfaces | Only in Then-vs-now / migration sections, or legacy-marked fences |
| Legacy marker | `// legacy: Next <16 implicit-caching model — see docs/evolution-ledger.md` |
| CI gates | `verify:code-blocks` → `verify:links` → `verify:legacy` → demo build → demo test |
| Package manager | pnpm workspaces; never `npm install` at docs root for the demo |

---

## 6. Phase structure

| Phase | Goal | Exit criteria |
| --- | --- | --- |
| 0 — Scaffold | This repo skeleton | Acceptance checklist in the scaffolding prompt |
| 1 — Spine articles | Wave 0–1 written against demo routes | All three verify gates green; demo build+test green |
| 2 — Recipes A–E | Symptom tracks for caching→mutations | Recipe index populated; cross-links to spine |
| 3 — Auth / perf / deploy | Waves 3 + tracks F/G/I | Ledger cites filled |
| 4 — Migration + ecosystem | Wave 4 + track H | Pages Router only as migration |

<!-- TODO: refine phase exit criteria once article inventory exists -->

---

## 7. First deliverables

<!-- TODO: empty on purpose — filled after article inventory approval -->

| Deliverable | Owner session | Status |
| --- | --- | --- |
| | | |

---

## Approval checklist

- [ ] §1 locked baseline reviewed (including Node/TS deltas)
- [ ] §2 stance accepted
- [ ] §3 article waves inventory filled and approved
- [ ] §4 recipe tracks filled and approved
- [ ] §5 conventions accepted
- [ ] §6 phase structure accepted
- [ ] §7 first deliverables named
- [ ] Evolution-ledger Cite column verified against bundled docs
- [ ] Next.js DevTools MCP registration confirmed or explicitly deferred
