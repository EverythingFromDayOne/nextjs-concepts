# Cursor — fix tooling before session 7

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/fix-tooling.md
Model:    channel default
Needs:    pnpm build · python3
```

Two small fixes surfaced by the environment build. Both are pre-existing; neither is an environment defect. Do these before session 7, because session 7 is the first article whose links should actually be checked.

---

## 1. `verify-links.mjs` decides by checkout path — it should decide by link target

**The bug.** Same-repo forward links are downgraded to warnings only when the checkout path contains the substring `nextjs-concepts`. GitHub CI checks out to `…/nextjs-concepts/nextjs-concepts`, so the substring matches and CI reports `0 broken link(s)`. A `/workspace` checkout doesn't match, so the same tree fails.

**Why it matters more than it looks.** Session 2 asked for **cross-repo** links to warn when the sibling repo isn't on disk. What got implemented tests *where this repo lives*, not *what the link points at* — which means the link gate has been in permanent warn mode on CI since session 2, and no article's links have ever actually been enforced. Wave 1 has passed a gate that was off.

**The fix.** Classify by target, and never by the checkout path:

| Link target | Behavior |
| --- | --- |
| `../../<sibling-repo>/…` — resolves outside this repo | **Warn** if absent. Cross-repo; sibling may not be checked out. |
| Anything else — resolves inside this repo | **Fail** if absent. |

Two sub-cases inside the second row, and I want them distinguished in the output rather than merged:

- **Missing file** — the target `.md` doesn't exist. Hard fail.
- **Missing anchor** — the file exists, the `#heading-slug` doesn't. Hard fail, and report the file and the slug. Guessed anchor slugs are a known repeat failure across this suite; this is the gate that should have been catching them.

Remove every reference to the repo name from the script's logic. If a path substring appears anywhere in a conditional, it's the bug.

**Prove it fires.** After the change, run from a `/workspace` checkout:

1. Full tree → report the real count. **Expect failures**, since the gate has never been enforced. Do not fix the articles in this session; list what broke.
2. Add a scratch link to `docs/concepts/foundations/thinking-in-the-app-router.md` pointing at `./definitely-not-a-file.md` → must fail naming file and line. Remove it.
3. Add one pointing at a real file with a bogus `#not-a-real-anchor` → must fail naming the slug. Remove it.
4. Confirm a `../../reactjs-concepts/…` link still only warns.

**If step 1 comes back clean, be suspicious** and say so — a gate that was off for six sessions finding nothing is a result worth doubting rather than celebrating.

## 2. `verify:templates` invokes `python`; it should invoke `python3`

The setup agent added the `python-is-python3` shim because the npm script calls bare `python`. The shim is the right environment fix and stays.

But the script depending on it means the repo only works where that shim exists — a fresh clone on a plain Ubuntu box hits exactly the wall the setup agent hit. Change the script to `python3`; keep the shim as belt-and-braces.

Check every npm script and workflow step for the same pattern, not just this one.

---

## 3. Report

- The real link-gate failure count, with the list. **Do not fix them here** — that's a separate pass once we know the size.
- Whether any other script depends on the shim.
- Confirmation that all four link-gate probes behaved as specified.

## Acceptance

- [ ] `verify-links.mjs` contains no repo-name substring test
- [ ] Cross-repo warns; same-repo missing file fails; same-repo missing anchor fails naming the slug
- [ ] All four probes run; scratch links removed
- [ ] Real failure count reported, unfixed
- [ ] `python3` in every script; shim retained
- [ ] Other gates still green
