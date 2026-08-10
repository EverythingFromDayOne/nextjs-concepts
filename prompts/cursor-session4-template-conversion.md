# Cursor — session 4: convert article 6 to `.md.tpl` (the pipeline proof-out)

`cache-components-model.md` becomes `cache-components-model.md.tpl`. It goes first because it now carries more measured content than anything else in the repo.

This session is as much about finding what the pipeline *can't* express as it is about converting one article. Report anything that doesn't fit rather than working around it silently.

---

## 1. Two demo conventions this needs first

### `demos/next-lab/antipatterns/` — wrong code that must never compile

Article 6's Common mistakes section shows code that is deliberately broken. It cannot live in `app/`, and hand-typing it defeats the extraction gate.

Create `demos/next-lab/antipatterns/`, add it to the demo's `tsconfig.json` `exclude` array alongside `legacy`, and give every file a header comment naming the failure mode:

```ts
// antipattern: 'use cache' on the page produces one coarse entry and
// forbids every runtime read below it. Extract-only; never compiled.
```

Files needed for article 6:

| File | Shows |
| --- | --- |
| `use-cache-on-page.tsx` | the directive at the top of a page |
| `identity-in-cached-scope.ts` | the caught form (mirrors `lib/billing-leak-a.ts`) |
| `page-tag.ts` | `cacheTag('dashboard')` instead of tagging the entity |
| `missing-cache-life.ts` | a cached scope with no `cacheLife` |

Where an antipattern has a *working* counterpart already in the demo (`billing-leak-{a,b,c}.ts`), extract from the working one and don't duplicate it here. `antipatterns/` is only for code that cannot exist in a compiling tree.

### `demos/next-lab/observations/` — recorded output as extractable text

Error text is code-like: verbatim-critical, easy to retype wrong, and it drifts across releases. Capture the session-3 measurements as `.txt` files so articles extract them and a Next upgrade that changes a message surfaces as a gate failure rather than a stale quote.

```
observations/sync-io-error.txt              # the new Date() prerender error, full text
observations/leak-a-runtime-error.txt       # the cookies()-in-cache error incl. digest
observations/leak-bc-curl.txt               # both curl responses, alice and bob
observations/alerts-minutes-build.txt       # build route table, cacheLife('minutes')
observations/alerts-seconds-build.txt       # build route table, cacheLife('seconds')
observations/insight-blocking-prerender.txt # dev log line + the 200 status
```

Each file gets a first line recording how it was produced: command, date, `next@16.3.0`. That line is part of the extraction, so the article shows its own provenance.

### `demos/next-lab/app/basic/` — the Basic usage route

Article 6's "Basic usage" section is currently a simplified inline example that exists nowhere. Build it: a route with one cached component and one cookie-reading component behind `<Suspense>`, matching the article's Announcements/Greeting shape. Basic usage should be runnable.

## 2. Conversion map — every fence in article 6

| # | Section | Current fence | Disposition |
| --- | --- | --- | --- |
| 1 | What it is | `next.config.ts` | `{EXTRACT:demos/next-lab/next.config.ts}` |
| 2 | How it works — keys | caught form (`cookies()` in cache) | `{EXTRACT:demos/next-lab/lib/billing-leak-a.ts#getDashboardLeakA}` |
| 3 | How it works — keys | the error message | `{EXTRACT:demos/next-lab/observations/leak-a-runtime-error.txt}` |
| 4 | How it works — keys | vector B, module capture | `{EXTRACT:demos/next-lab/lib/billing-leak-b.ts}` — whole file, the module-level `let` is the point and a symbol extract would hide it |
| 5 | How it works — keys | vector C, coarse key | `{EXTRACT:demos/next-lab/lib/billing-leak-c.ts#getDashboardLeakC}` |
| 6 | Basic usage | the whole example | `{EXTRACT:demos/next-lab/app/basic/page.tsx}` |
| 7 | Walkthrough Step 0 | Next-15 before | `{EXTRACT:demos/next-lab/legacy/dashboard-page.next15.tsx}` — **replaces the stopgap marker; the marker arrives with the file** |
| 8 | Step 1 | config snippet | same as #1, or a line range if the article wants only the two keys |
| 9 | Step 3 | `getPlans` / `getUsage` | `{EXTRACT:…/lib/billing.ts#getPlans}`, `#getUsage` |
| 10 | Step 3 | `getAlerts` | `{EXTRACT:…/lib/status.ts#getAlerts}` |
| 11 | Step 4 | dashboard page | `{EXTRACT:demos/next-lab/app/dashboard/page.tsx}` |
| 12 | Step 5 | `pnpm build && pnpm start` | **stays authored** — shell commands, no demo source |
| 13 | Step 5 | the lifetime observation | `{EXTRACT:…/observations/alerts-minutes-build.txt}` and `alerts-seconds-build.txt` |
| 14 | Mistakes #2 | `'use cache'` on a page | `{EXTRACT:…/antipatterns/use-cache-on-page.tsx}` |
| 15 | Mistakes #3 | the leak | reuse #4 |
| 16 | Mistakes #4 | missing `cacheLife` | `{EXTRACT:…/antipatterns/missing-cache-life.ts}` |
| 17 | Mistakes #8 | sync-IO error | `{EXTRACT:…/observations/sync-io-error.txt}` |
| 18 | Mistakes #9 | page tag vs entity tag | `{EXTRACT:…/antipatterns/page-tag.ts}` |

Everything not listed — tables, prose, the three-clocks and threshold tables — is prose and stays in the template as-is.

**Any fence you find that isn't on this list:** stop and report it rather than guessing a spec. A missing row means either I missed a fence or the article changed since I mapped it, and both are worth knowing.

## 3. Prose that must change alongside the extraction

- **Step 5, item 3** currently says to check page source. Point it at `.next/server/app/dashboard.html` per the §2 correction. If any walkthrough step still says "view source," it was missed in the last pass.
- **Demo source footer** — list every path this article now extracts from, including `antipatterns/` and `observations/`.
- **Verification status block** — rewrite. Sync-IO, lifetime-placement, the leak vectors, and the insight are now *measured*, not pending. What remains pending should be named honestly; if nothing does, say so.
- **`instant = false` silences the insight.** Session 3 established this by shipping the probe with the flag to keep builds green. Add one line where `instant = false` is introduced: it is the acknowledgement that quiets the validator, which is precisely its purpose and precisely why it should be temporary.

## 4. Flip the status and prove `--strict`

Once the template builds and the output matches:

1. Change frontmatter `status: draft` → `status: review`.
2. Run `verify-code-blocks --strict`. It should pass — every fence is sourced except #12.
3. **Then deliberately break it:** change one character in `lib/billing.ts`, re-run without rebuilding. Confirm exit 1 naming the file and line. Restore.

Step 3 is the actual proof-out. A gate that has never failed on real content is not known to work.

## 5. Report

Beyond the four blocks, answer three questions directly:

1. **What didn't fit?** Any fence where extraction was awkward, any spec form the extractor doesn't support, any place the template made the prose worse.
2. **How long did the conversion take**, roughly? Forty-four more articles follow this path; if it's expensive, the format needs adjusting now.
3. **Does the built `.md` read as well as the hand-written one?** If extraction reordered, reformatted, or stripped something that mattered, that's a pipeline defect, not an article defect.

---

## Acceptance

- [ ] `antipatterns/` and `observations/` created; both excluded from tsconfig where applicable
- [ ] `app/basic/` built and reachable
- [ ] `cache-components-model.md.tpl` exists; `build-article.py` produces the `.md`
- [ ] Every fence in §2 converted; unlisted fences reported, not guessed
- [ ] Step 0's stopgap `// legacy:` line is gone — it now arrives via extraction
- [ ] `status: review`; `verify-code-blocks --strict` passes
- [ ] Induced drift produces exit 1 with file:line; restored
- [ ] Full gate chain green
- [ ] The three §5 questions answered
