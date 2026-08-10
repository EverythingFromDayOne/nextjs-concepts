# Cursor — session 2 corrections (small, do before session 3)

Session 2 accepted. Three corrections, one of which is a spec bug of mine that you worked around correctly but in the wrong place.

---

## 1. `experimental.useTypeScriptCli: true` is a no-op — remove it

Verified against the official reference (`useTypeScriptCli`, last updated 2026-08-03): **the CLI checker is enabled by default.** The flag exists so you can set it to `false` and go back to the TypeScript JavaScript compiler API. Setting it to `true` writes down the default and nothing else.

Two consequences:

- **Remove the key** from `demos/next-lab/next.config.ts`, or keep it with a comment saying it's the default and only exists here for visibility. Either is fine; leaving it bare implies it's load-bearing.
- **The roadmap §1 framing is wrong and I wrote it.** It reads as though TS 7 requires `useTypeScriptCli`. It does not: install `typescript@^7` and `next build` uses the project-local `tsc`. Correct §1 to say **"TypeScript 7.0.2. No configuration required — the project-local `tsc` CLI is the default checker."** The flag is an opt-*out*, and it's marked experimental and not recommended for production, which is worth one clause.

Also record these in `progress.md` as article-43 material, because they are the non-obvious part and we will not rediscover them later:

- TS 7 installs **side by side** with TS 6. `node_modules/typescript` remains TS 6; TS 7 lives under a different folder; `npx tsc` is the Go compiler and `tsc6` the old one. Delete `node_modules` and the lockfile before reinstalling, or the resolution is wrong in a way that looks like a Next bug.
- CLI type checking prints native `tsc` diagnostics — no Next.js code frames, no route/page/layout error rewriting. It also checks the **complete project** selected by `tsconfig`, including test files and `.next/dev/types`.
- `typescript.ignoreBuildErrors` skips the CLI checker too.

## 2. Revert the legacy-gate softening — the rule was wrong, not the gate

You softened `verify-legacy-markers` so hits in `status: draft` warn instead of failing, which cleared 6 warnings across the three articles.

**Revert that.** The softening is right for `verify-code-blocks` — a draft legitimately carries authored code — but wrong here. The legacy gate is the mechanized form of the repo's thesis, and articles live in draft for weeks. A gate that only fires after the content is finished never fires on the content it was built for.

The 6 warnings are **true positives against a rule I specified too narrowly.** A "Common mistakes" section has to name the dead API in order to tell people not to write it:

> **9. Copying `export const dynamic = 'force-dynamic'` from a tutorial.** Under `cacheComponents` this is a build error rather than a no-op…

That is exactly the sentence the repo exists to produce, and the current rule bans it.

**Fix the rule instead.** Extend the allowed-context heading pattern from:

```
/then vs now|how this evolved|migration/i
```

to:

```
/then vs now|how this evolved|migration|common mistakes/i
```

Then restore hard-fail for every status. Re-run against the three articles: all 6 warnings should resolve to passes without touching the prose. If any survive, that one is a real violation and I want it named in your report rather than fixed silently.

Same treatment for the missing forward/sibling-link softening in `verify-links`: keep warn-on-draft there, since Wave 1 articles legitimately link to Wave 5 files that don't exist yet. That one is a genuine forward-reference problem, not a rule bug. Note the distinction in the script header so the two policies don't get unified by a future edit.

## 3. Declare the still-live API exclusions in the ledger, don't infer them

Excluding `cookies()`, `headers()`, and `searchParams` from the ban list was correct and important — banning `cookies()` would have been catastrophic. But it exposes a design flaw in the ledger that I own.

The "Old surface" column conflates two different kinds of row:

- **Removed or renamed** — `export const dynamic`, `unstable_cache`, `noStore()`, `experimental_ppr`, `middleware.ts`, `dynamicParams`. These must be banned.
- **Still live, behavior changed** — `cookies()`, `headers()`, `searchParams`, `generateStaticParams`, `revalidateTag`. These must not be.

Right now that distinction lives in your exclusion list rather than in the data, so the next person to add a ledger row gets it right or wrong by accident.

**Add an explicit `Ban` column** (`yes` / `no`) to `docs/evolution-ledger.md` and have `verify-legacy-markers.mjs` read the ban list from it rather than from the "Old surface" column with an exclusion filter. Fill it for all 22 existing rows. Where a row is `no`, the reason is usually "API still exists, semantics changed" — put that in the existing `Kind of change` column if it isn't already clear.

Then delete the hardcoded exclusion list from the script. A ban list that lives in two places will diverge.

---

## Acceptance

- [ ] `useTypeScriptCli` removed or commented as the default; roadmap §1 reworded to "no configuration required"
- [ ] Three TS 7 gotchas recorded in `progress.md` as article-43 material
- [ ] Legacy gate hard-fails for all statuses again; heading pattern includes `common mistakes`
- [ ] All 6 previous warnings resolve without prose edits — **any survivor named in your report**
- [ ] Link gate keeps warn-on-draft, with the two policies distinguished in a header comment
- [ ] Ledger has a `Ban` column, filled for all 22 rows
- [ ] Script reads the ban list from that column; hardcoded exclusion list deleted