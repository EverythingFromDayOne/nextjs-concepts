# Cursor — session 16: recipe #1 (`caching/everything-went-dynamic-after-the-upgrade`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session16-recipe1-demos.md
Model:    channel default
Needs:    pnpm build (repeatedly) · pnpm start + curl · python3
```

The recipe most readers arrive for. Second use of `RECIPE_TEMPLATE.md`, now including the `What doesn't work` section session 11 added.

**One experiment, run in stages**, and the stages *are* the recipe: take real Next-15-shaped code, turn Cache Components on, and record the cascade in the order a person would actually hit it.

---

## 1. The starting point

`legacy/dashboard-page.next15.tsx` already holds the before-state — tsconfig-excluded and never compiled. This session compiles it, on purpose, to find out what a reader sees.

Copy it into a real route at `app/upgrade-lab/page.tsx`, adjusting only imports so they resolve against this repo's demo data. **Change nothing else** — not the segment config exports, not `unstable_cache`, not the `Promise.all`, not `new Date()`. The point is what unmodified Next 15 code does.

## 2. EXPERIMENT — the cascade, stage by stage

Build after each stage. Capture the **full error output** each time, then fix only what that stage's error names and build again.

→ `observations/upgrade-cascade.txt`, one section per stage, each with its provenance line.

| Stage | Expected to surface |
| --- | --- |
| 0 | Baseline build with the route unmodified |
| 1 | Segment config exports — `dynamic`, `revalidate`, `fetchCache` |
| 2 | `unstable_cache` |
| 3 | Synchronous IO — `new Date()` |
| 4 | Runtime reads above every boundary — `cookies()` at the page root |
| 5 | Whatever remains once those are gone |

**The ordering is the finding.** A reader fixes what the build tells them, rebuilds, and gets a different error — I want the real sequence, not my guess at it. If the compiler surfaces several at once, or in a different order, say so; that changes how the recipe is staged.

**Also record at each stage:** the route's build-table row. Watching it move from absent → `ƒ` → `◐` is the visible arc of the recipe, and it's the evidence for the claim that things get worse before they get better.

## 3. The end state, measured

Once the route builds clean, capture the comparison the recipe is built around:

1. **Build table row** for `/upgrade-lab` versus `/dashboard` (already correctly migrated).
2. **`.next/server/app/upgrade-lab.html`** — what's in the shell.
3. **A deliberate intermediate state:** the route building but with everything dynamic — no `'use cache'` anywhere. Capture its build row and shell.

→ `observations/upgrade-before-after.txt`

Item 3 is important and easy to skip. It's the state a reader lands in after clearing the errors, and it is **worse than what they had** — the article claims this and it should be shown, not asserted.

## 4. The codemod

Roadmap notes a trap: `cache-components-instant-false` takes `./app`, not `./src/app`, and reports `0 ok` rather than erroring on a wrong path. This repo has no `src/`, so:

1. Run it against `./app` in the demo. What does it report, and what does it change?
2. Run it against a **deliberately wrong path**. Confirm the silent `0 ok`.
3. Does adding `instant = false` to `/upgrade-lab` in its all-dynamic state change the build row or the shell?

→ `observations/codemod-instant-false.txt`

**Revert everything the codemod touches afterwards** except `/upgrade-lab`, which the recipe keeps as its demo source.

## 5. What doesn't work — candidates to test

The recipe's `What doesn't work` section needs measured negatives, not speculation. Test these two:

1. **Keeping `export const dynamic = 'force-dynamic'`** as a way to postpone the migration. Does it error, or is it accepted?
2. **`instant = false` everywhere** as a permanent state. Does the app build? What does it cost — check build rows and shells across the routes the codemod touched.

Both are things a reader under time pressure will reach for. If either works, the recipe says so honestly. If they don't, that's the section's content.

→ append to `observations/upgrade-cascade.txt`

## 6. Template

`prompts/session16/everything-went-dynamic-after-the-upgrade.md.tpl` ships with this. Placeholders:

- `{ERROR_CASCADE}` — §2, in the real order
- `{BEFORE_AFTER}` — §3, all three states including the intermediate
- `{CODEMOD_RESULT}` — §4
- `{DOESNT_WORK}` — §5

Move to `docs/recipes/caching/` as the final step, add a row to `docs/recipes/index.md`, and confirm the recipe path is in roadmap §4's planned-recipes list — it should be, from the manifest fix.

---

## Acceptance

- [ ] `app/upgrade-lab/` created from the legacy file with only imports adjusted
- [ ] Cascade captured stage by stage in the **actual** order, with build rows
- [ ] The intermediate all-dynamic state captured — the one that's worse than before
- [ ] Codemod run against both a correct and a wrong path; silent `0 ok` confirmed
- [ ] Both `What doesn't work` candidates tested
- [ ] Codemod changes reverted except `/upgrade-lab`
- [ ] Placeholders filled from `observations/`; recipe index and roadmap §4 checked; gates green
- [ ] Report whether `RECIPE_TEMPLATE.md` held up on its second use, including the new section
