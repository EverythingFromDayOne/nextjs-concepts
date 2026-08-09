# Progress

Living status board. Plan lives in `roadmap.md`.

## Legend

| Mark | Meaning |
| --- | --- |
| ✅ | Landed and gates green |
| 🟢 | Draft complete, awaiting review |
| 🟡 | In progress |
| ⚪ | Not started |
| ❌ | Blocked / failed verification |

---

## Wave 0 — foundations

| Slug | Status | Notes |
| --- | --- | --- |
| | ⚪ | |

## Wave 1 — rendering + caching spine

| Slug | Status | Notes |
| --- | --- | --- |
| | ⚪ | |

## Wave 2 — routing + data + mutations

| Slug | Status | Notes |
| --- | --- | --- |
| | ⚪ | |

## Wave 3 — auth + performance + deployment

| Slug | Status | Notes |
| --- | --- | --- |
| | ⚪ | |

## Wave 4 — ecosystem + migration

| Slug | Status | Notes |
| --- | --- | --- |
| | ⚪ | |

---

## Open questions / TODOs

- [ ] Fill `roadmap.md` §3 article inventory (Claude session — do not invent ad hoc)
- [ ] Fill `roadmap.md` §4 recipe titles (symptom-first)
- [ ] Verify every evolution-ledger Cite against `next/dist/docs/`
- [ ] Port `verify-code-blocks.mjs` and `build-article.py` from a sibling when available (`dsa-concepts` / `reactjs-concepts` scripts were absent at scaffold time)
- [ ] Confirm Turbopack + filesystem cache messaging from a real `next build` log and lock the wording in roadmap §1
  - Turbopack confirmed (`Next.js 16.3.0 (Turbopack)`, `Cache Components enabled`). Filesystem-cache line not printed — still open.
- [ ] Decide whether to bump demo `typescript` from `^5` / resolved `5.9.3` toward registry `7.x` after verifying `next build` typecheck support
- [ ] Register Next.js DevTools MCP in Cursor config once the install-time mechanism is confirmed — see `.cursor/mcp.json.todo`
- [ ] Choose a real test runner for `next-lab` (currently `node --test` placeholder)

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
