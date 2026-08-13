# Cursor — extend the link manifest to recipes

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/fix-recipe-manifest.md
Model:    channel default
Needs:    python3 (no build required)
```

Small and blocking. **Run this before session 11 or 12.**

---

## The hazard

`verify-links.mjs` classifies a same-repo link to a missing file by checking whether the path appears in `roadmap.md` §3. §3 lists **47 concept articles**. It lists **no recipes**.

Article 1's template (session 12) links to `../../recipes/caching/user-a-sees-user-b-data.md`, which session 11 creates. Run 12 before 11 and that link is *missing and unplanned* — a hard failure, not a planned-forward warning.

This isn't specific to those two sessions. Every article that cites a recipe hits it, and recipes are cited deliberately: the concept articles are supposed to hand off to symptom-first guides.

## The fix

**Add a recipe manifest to `roadmap.md` §4** and have the link gate parse both §3 and §4.

§4 currently lists nine tracks in priority order but no individual recipes. Extend it with a *Planned recipes* subsection listing recipe paths as they get specified. Seed it with the three from §8:

```
recipes/caching/everything-went-dynamic-after-the-upgrade
recipes/caching/user-a-sees-user-b-data
recipes/mutations/action-succeeded-ui-didnt-update
```

Use whatever format parses most reliably alongside §3 — if §3's numbered-list format is what the parser already handles, match it rather than inventing a second shape.

Then update `verify-links.mjs` so the manifest is the union of §3's articles and §4's recipes. **One parser, two sections** — do not add a second code path, and do not hardcode any of it.

## Verify all four buckets still behave

The failure path has been proven once and this change touches the manifest it depends on. Re-run the probes:

| Link | Expected |
| --- | --- |
| `../../recipes/caching/user-a-sees-user-b-data.md` (missing, now in §4) | **planned-forward warn** |
| `../../recipes/caching/not-a-planned-recipe.md` (missing, not in §4) | **hard fail** |
| `./caching/not-a-planned-article.md` | **hard fail** |
| `../../../../reactjs-concepts/docs/concepts/nope.md` | **cross-repo warn** |

Use scratch links, then delete them. Report the actual classification for each, not a confirmation.

## Report

- The three-bucket count after the change
- Whether any *existing* link in the repo was reclassified by it — a link that was hard-failing and now warns, or vice versa
- Whether §4 parsed cleanly, or whether its format needed changing to be parseable

## A note on sequencing

Once this lands, sessions 8–12 can run in any order. Without it, 12 depends on 11. Worth knowing which constraint you're operating under.

---

## Acceptance

- [ ] §4 carries a parseable planned-recipes list, seeded with the three from §8
- [ ] `verify-links.mjs` reads §3 and §4 through one parser; nothing hardcoded
- [ ] All four probes run and reported; scratch links removed
- [ ] Any reclassified existing links named
- [ ] Gates green
