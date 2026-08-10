# Cursor — link policy, depth bug, and a staging convention

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/fix-links-policy.md
Model:    channel default
Needs:    pnpm build · python3
```

Merge PR #1 first. Then four things — §1 is the one that unblocks CI.

Your call to drop the draft-softening exception was right given the two-way policy, and it exposed something the old gate was hiding. But two-way isn't enough: there's a third category, and without it the gate stays red until article 47.

---

## 1. Forward links need a third classification — validate against the roadmap

Most of the 20 failures are links from Wave 1 articles to Wave 2–6 articles that aren't written yet. Every article's "See also" section points forward by design. Under a strict two-way policy, CI is red for the life of the project.

But the answer isn't to soften it again. It's that **a link to a planned article and a link to a typo are different things, and the roadmap already knows which is which.**

`roadmap.md` §3 lists all 47 articles by `concept_folder/article-id`. Use it as a manifest:

| Link target | Behavior |
| --- | --- |
| Resolves outside this repo | **Warn** — cross-repo, sibling may not be checked out |
| Same-repo, file exists | **Check the anchor**; fail if the `#slug` is absent |
| Same-repo, file missing, **but the path appears in roadmap §3** | **Warn** — planned, unwritten |
| Same-repo, file missing, **not in roadmap §3** | **Fail** — typo or a link to something nobody planned |

That last row is the one worth having. `caching/cache-lifetimes.md` is a legitimate forward reference; `caching/cache-lifetimez.md` is a typo, and only the manifest can tell them apart. Guessed slugs and misspelled paths are the known repeat failure in this suite — this is the gate that should catch them.

Parse §3 rather than hardcoding a list. If parsing is unreliable, say so and propose a format change to §3 instead of maintaining a second copy.

**Report the count in three buckets:** cross-repo warns, planned-forward warns, and hard failures. The third number is the one that must reach zero.

## 2. The cross-repo depth bug — mine, in two places

From `docs/concepts/<folder>/`, escaping to a sibling repo takes **four** levels:

```
docs/concepts/foundations/  →  docs/concepts/  →  docs/  →  <repo root>  →  experimental-projects/
```

So: `../../../../reactjs-concepts/docs/concepts/<path>.md`

Both the articles and the roadmap are wrong, by different amounts:

- **Articles** use three `../`. Fix all four occurrences.
- **Roadmap §2** states the convention as `../../reactjs-concepts/…` — two. Fix the stated convention, and add the derivation above so nobody recomputes it wrong a third time.

After fixing, confirm those four now classify as **cross-repo warns** rather than same-repo failures. If they still resolve inside the repo, the depth is still wrong.

## 3. `verify:templates` is failing because of my ordering mistake

Article 8's `.tpl` is in `docs/` and its `{EXTRACT:}` tokens point at demo files session 7 hasn't created yet. That's not a content gap — it's a workflow flaw I introduced by telling you to push the template alongside the prompt.

**New convention:** a template ships in `prompts/<session>/` and the session **moves** it into `docs/` as its final step, after its demos exist. The gate only scans `docs/`, so an in-flight template never breaks the chain.

Apply it now:

```
docs/concepts/foundations/rules-of-the-server-boundary.md.tpl
  →  prompts/session7/rules-of-the-server-boundary.md.tpl
```

Record the convention in roadmap §5 under "The extraction pipeline." Session 7's prompt will need its §4 adjusted to move the file; do that as part of this task so the two stay consistent.

`verify:templates` should go green immediately after the move.

## 4. Then fix the real breaks

Once §1–§3 land, re-run and fix whatever remains in the hard-failure bucket. Those are genuine — wrong paths, wrong anchors, articles referenced under names that were later changed. Wave 1 has been through several renames (`routing/metadata` → `seo/metadata`, article renumbering 42 → 47), so expect stale targets.

**Anchors especially.** Report each anchor failure as `file:line — target#slug (available: …)` with the real headings, so fixing them doesn't require opening both files.

---

## A note on why this keeps happening

This is the second gate to have been effectively disabled by its own specification. The legacy gate was too narrow, so it got softened for drafts; the link gate classified by checkout path, so it always warned. Both times the cause was the same: **I specified the gate before writing content against it.**

The pattern to watch for: when a gate fires on something legitimate, the fix is almost never to soften it. It's that the rule was missing a category. Softening removes the gate; adding a category keeps it. Worth one line in `AGENTS.md`, because there are three more gates and 39 more articles.

---

## Acceptance

- [ ] PR #1 merged
- [ ] Four-way classification implemented; roadmap §3 parsed, not duplicated
- [ ] Counts reported in three buckets; hard failures reach zero
- [ ] Cross-repo depth fixed in articles and roadmap §2, with the derivation recorded
- [ ] Those four links now classify as cross-repo warns
- [ ] Template moved to `prompts/session7/`; convention in roadmap §5; session 7 prompt's §4 updated to match
- [ ] `verify:templates` green
- [ ] Anchor failures reported with available headings
- [ ] Full gate chain green
