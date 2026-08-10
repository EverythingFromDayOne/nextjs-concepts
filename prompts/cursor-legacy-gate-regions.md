# Cursor — legacy gate, third allowed form (small)

Your survivor list was correct on all five. One is a real violation of mine; four are a gap in the rule. Both fixes below.

---

## 1. The real violation — article 6, lines 216–217

The Walkthrough Step 0 fence is the Next-15 "before" code and I wrote it without the marker. Add it as the first line inside the fence:

```tsx
// legacy: Next <16 implicit-caching model — see docs/evolution-ledger.md
export const dynamic = 'force-dynamic'
export const revalidate = 60
...
```

**This is a stopgap.** Session 3 creates `demos/next-lab/legacy/dashboard-page.next15.tsx` with that marker already on line 1, precisely so the article extracts it rather than carrying a hand-written copy. When article 6 converts to `.md.tpl`, this fence becomes `{EXTRACT:demos/next-lab/legacy/dashboard-page.next15.tsx}` and the marker arrives with it. Add the line now to unblock CI; expect it to be replaced.

## 2. The rule gap — add region markers

Lines 51, 52, and 80 are legitimate content the rule cannot express. The gate currently recognizes two allowed forms:

1. inside a section whose nearest heading matches `/then vs now|how this evolved|migration|common mistakes/i`
2. inside a fenced block preceded by the `// legacy:` comment

Neither covers a **markdown table row** or an **inline prose mention** — and both are unavoidable in an article whose job is explaining what the old model was.

Add a third form:

```markdown
<!-- legacy-ok:start reason=<non-empty reason> -->
…content permitted to mention banned surfaces…
<!-- legacy-ok:end -->
```

Rules:

- `reason=` must be present and non-empty. A bare `<!-- legacy-ok:start -->` **fails**, and the failure message should say the reason is missing. The friction is the point: a marker you can add without thinking is a rubber stamp.
- An unclosed `legacy-ok:start` at EOF **fails**. Otherwise a stray marker silently whitelists the rest of the file.
- Nesting is not supported; a second `start` before an `end` **fails**.
- Regions are per-file and do not cross files.

### Reporting — this is what keeps the form honest

The script's summary line must include a count:

```
verify-legacy-markers: 3 file(s); 0 failure(s); 4 legacy-ok region(s) across 2 file(s)
```

And with `--verbose`, list each region as `file:line — reason`. A file that accumulates a dozen regions should be visible in CI output without anyone going looking. The gate stops being a gate the moment the escape hatch is invisible.

## 3. Apply to article 6

Wrap the two spots, with real reasons:

- The four-layer table in **"What it is"** — `reason=historical description of the pre-16 four-layer cache model`
- The `experimental.ppr` sentence in **"How it works"** — `reason=names the removed PPR flags as removed`

Then re-run. Expected: **0 failures, 2 legacy-ok regions in one file**, plus the marker fix from §1 clearing 216–217. Prose unchanged throughout.

## 4. Record the rule

Add the third form to `AGENTS.md` alongside the existing marker comment, and to roadmap §5 under "Legacy surfaces". A rule that lives only in a script gets rediscovered by trial and error.

---

## Acceptance

- [ ] Article 6 fence at ~216 carries the `// legacy:` marker as its first line
- [ ] `legacy-ok:start/end` implemented with a mandatory `reason=`
- [ ] Missing reason, unclosed region, and nested region each **fail** — verify all three with throwaway fixtures, then delete them
- [ ] Summary line reports region count; `--verbose` lists `file:line — reason`
- [ ] Article 6's two regions wrapped; full gate chain green with 0 failures
- [ ] Third form documented in `AGENTS.md` and roadmap §5
