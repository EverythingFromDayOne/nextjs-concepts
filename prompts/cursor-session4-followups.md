# Cursor — session 4 follow-ups, and a workflow change

Session 4 accepted. Your three pipeline gaps were all my bugs; your five unlisted-fence calls were all correct. Three things below: one extractor change, one workflow change, four small fixes.

---

## 1. Extractor — resolve imports for symbol extracts

Your sharpest finding: `{EXTRACT:lib/billing.ts#getPlans}` produces a block with no `import` lines, so a reader can't run it. That is a real defect and it will recur in every article.

**Change `scripts/lib/extract.mjs` so symbol extracts emit the imports the region actually uses.**

Algorithm:

1. Parse the file's leading import statements into `(statement, [bound names])`. Handle default, named, namespace, and aliased forms (`import { cacheLife as cl }` binds `cl`).
2. Extract the symbol region as today.
3. Scan the region for word-boundary occurrences of each bound name.
4. Emit only the matching import statements, in source order, then a blank line, then the region.

So `#getPlans` yields:

```ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

export async function getPlans() {
  …
}
```

but not the twelve unrelated imports a larger file might carry.

**Opt out with `#getPlans-imports`** where a block is deliberately a fragment. Whole-file and line-range extracts are unaffected — they already carry whatever the range contains.

Two edge cases to get right, both with fixtures: a type-only import (`import type { Product }`) used only in a type position must still be matched; and a name that appears only inside a string or comment must **not** count as a use. Getting the second wrong makes blocks noisier, not broken, so prefer the false positive if the scan is ambiguous — but write down which way you chose.

Re-run article 6's build afterward. Blocks will grow; that is the point.

## 2. Workflow change — articles are authored as `.tpl` from now on

Your 45–60 minute figure, times 44 remaining articles, is roughly 37 hours of pure transcription. That cost exists only because article 6 was written as finished `.md` and converted afterward.

**From article 5 onward, Claude delivers `<article>.md.tpl` plus its demo sources in the same turn.** No `.md` is hand-written and no conversion step exists. Your job becomes: place the files, run `build-article.py`, run the gates, report.

Record in roadmap §5 under "The extraction pipeline":

> Articles are authored as `.md.tpl` with `{EXTRACT:}` tokens and delivered alongside their demo sources. The `.md` is a build artifact and is never edited by hand. Articles 1, 2, and 6 predate this rule; 6 was converted, 1 and 2 are converted opportunistically.

Two consequences worth writing down:

- **Demo sources are article content.** Your note about `rememberUid` and the `getAlerts` JSDoc being noise the hand-typed version trimmed is the right read — but the conclusion is that demo files should be *written for extraction*, not that extraction is lossy. That discipline is mine to hold from article 5 on.
- **Observations get batched.** Capturing them one article at a time is where your hour went. Where an article needs recorded output, the demo delivery names every command up front so they run in one pass.

## 3. Four fixes in article 6

1. **"One config line" is now false.** The extracted `next.config.ts` shows imports plus two keys. Change the prose to *"one decision"* rather than one line, or use a line-range extract for the two keys. Prefer fixing the prose — the config genuinely isn't one line.
2. **`getUsage` appearing twice is fine — leave it.** Once as the correct form immediately after vectors B and C, once in the walkthrough. The repetition is doing work in both places. Not a defect.
3. **`bash`/`sh`/`shell` unsourced allowance needs reporting.** Same reasoning as `legacy-ok` regions: an exemption nobody can see stops being an exemption. Add the count to `verify-code-blocks`'s summary line — `N sourced / M unsourced-shell / K failures`.
4. **Add the `instant = false` line** if it didn't land: shipping the insight probe with the flag to keep builds green demonstrates that `instant = false` silences the validator. That is precisely its purpose, and precisely why it should be temporary. One sentence where the flag is introduced.

---

## Acceptance

- [ ] Symbol extracts carry their used imports; `-imports` opts out
- [ ] Both edge-case fixtures written, run, deleted; the chosen behavior for the ambiguous case recorded
- [ ] Article 6 rebuilt with import-carrying blocks; gates green
- [ ] Roadmap §5 records the `.tpl`-first rule
- [ ] Four article-6 fixes applied
- [ ] `verify-code-blocks` summary reports the unsourced-shell count
