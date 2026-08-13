# Cursor — session 7: article 8 (`foundations/rules-of-the-server-boundary`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session7.md
Model:    channel default
Needs:    pnpm build (repeatedly) · python3 · no running server required
```

This session is **one experiment with eleven probes**. Article 8's thesis is that the boundary rules are not equally enforced — some are build errors, some are runtime errors, some are silent — and the enforcement matrix is the article. Everything else is consolidation of sessions 3–6.

Almost no new demo code. Mostly scratch probes that get built, captured, and deleted.

---

## 1. The enforcement matrix — eleven probes

**Method, and it matters:** a build error is fatal, so probes cannot coexist. Run them **one at a time**:

```
add probe → pnpm --filter next-lab build → capture → if it built, pnpm start + curl → capture → remove probe
```

Capture everything into a single `observations/enforcement-matrix.txt`, one block per probe, each headed with the probe name. Provenance line at the top of the file as usual.

For each probe record exactly three things:

- **build** — pass or fail, with the error's first line verbatim
- **runtime** — if it built: does requesting the route throw, and what does it say
- **silent?** — if neither errors, what actually happens to the value

| # | Probe | Where |
| --- | --- | --- |
| 1 | `'use cache'` on a **non-async** function | new fn in a scratch lib |
| 2 | `cacheLife()` called at **module scope** | scratch lib |
| 3 | `cookies()` inside a cached scope | reuse `lib/billing-leak-a.ts` — already measured, re-confirm only |
| 4 | `connection()` inside a cached scope | scratch lib |
| 5 | `new Date()` inside a cached scope | reuse `lib/stamped.ts` — already measured, re-confirm only |
| 6 | `useState` in a **Server Component** | scratch route |
| 7 | `onClick` handler on an element in a Server Component | scratch route |
| 8 | Server Component **imported** into a Client Component | scratch pair |
| 9 | A **function** passed as a prop across the client boundary | scratch pair |
| 10 | A **class instance** passed as a prop across the boundary | scratch pair — define a tiny class with a method, read the method on the client |
| 11 | A **non-async** export in a `'use server'` file | scratch actions file |

**Probe 10 is the one I most want the answer to.** My articles claim the fields arrive and the methods don't — that it fails *silently* into a shape that looks right and answers `undefined`. If Next actually rejects it at build or runtime, that claim is wrong in two articles and needs correcting. Read the method on the client and record what you get.

Probes 3 and 5 are already measured; re-run them only to confirm nothing changed, and note if it did.

## 2. Antipatterns to keep (extract-only, tsconfig-excluded)

Only these four survive as permanent files, because the article shows their code. The rest are scratch and get deleted.

```
antipatterns/non-async-cached-fn.ts        # probe 1
antipatterns/hooks-in-server-component.tsx # probe 6
antipatterns/imported-server-component.tsx # probe 8
antipatterns/class-instance-prop.tsx       # probe 10
```

Each keeps the `// antipattern:` header naming the failure mode, and — new for this article — a second line recording **how it fails**: `// fails: build` / `// fails: runtime` / `// fails: silently`. That line comes from your measurement, not from me.

## 3. One question left open from the shakedown

The route-level **Revalidate/Expire** column now has three observations that don't fit a single rule:

- `/dashboard`, alerts at `cacheLife('seconds')` → `1d 1w`
- `/dashboard`, alerts at `cacheLife('minutes')` → `1m 1h`
- `/streaming-coarse` → `1h 1d`, for a cached entry session 5 measured as **absent** from that route's prerender

"Shortest lifetime among prerendered entries" fits the first two and breaks on the third.

**One cheap probe, if the eleven above go smoothly:** add a second cached function to `/streaming-coarse` with `cacheLife('minutes')` and rebuild. If the column moves to `1m 1h`, it tracks the shortest entry regardless of shell membership; if it stays `1h 1d`, something else is going on.

→ `observations/route-lifetime-column.txt`

**If it stays ambiguous, say so.** Article 10 will tell readers the column cannot be interpreted, and an honest "we could not derive it" is the finding. Do not guess a rule.

## 4. Template

`prompts/session7/rules-of-the-server-boundary.md.tpl` ships alongside — in `prompts/session7/`, not `docs/`, per the new staging convention (roadmap §5, "The extraction pipeline"): a template whose `{EXTRACT:}` tokens point at demos that don't exist yet stays out of `docs/` so it can't break `verify:templates` for anyone else while this session is in flight. It contains an enforcement-matrix table with `{ENFORCEMENT_MATRIX}` as a **prose placeholder** — the builder will refuse to build until it is filled from your measurements. That is deliberate: the table is the article, and it must not be authored by me.

Fill it from `observations/enforcement-matrix.txt`, then, as the session's **final step**, move the template into its real location and build it there:

```bash
mkdir -p docs/concepts/foundations
git mv prompts/session7/rules-of-the-server-boundary.md.tpl docs/concepts/foundations/rules-of-the-server-boundary.md.tpl
python3 scripts/build-article.py docs/concepts/foundations/rules-of-the-server-boundary.md.tpl
pnpm verify
```

Do not build or verify it in place under `prompts/session7/` — the gate only scans `docs/`, so nothing checks it there, and the move is the step that turns it into a real article. Ships at `status: draft` until the matrix is complete.

## 5. Housekeeping — fold in, don't spend a session on it

- **`grep -rn "insight" docs/`** — your experiment showed the dev log prefix is `Error:`, not "Insight." Every use of the word as a *severity* is wrong and should become the dev/build enforcement split. **Instant Insights** is a real 16.3 DevTools feature and keeps its name; leave those.
- **Article 4, `instant = false`** — the shakedown shows `/insight-probe` as `ƒ` Dynamic. The flag doesn't just permit blocking, it costs the segment its shell. One sentence.
- **Article 10 note in the roadmap** — upgrade from "the route-level column is a leftover of route-level thinking" to "do not read it as the page's lifetime," pending §3.

---

## Acceptance

- [ ] All eleven probes run serially; `enforcement-matrix.txt` has build / runtime / silent for each
- [ ] Probe 10 answered explicitly — silent, or not
- [ ] Four antipattern files kept, each with a measured `// fails:` line; all scratch removed
- [ ] §3 probe run and reported, including "still ambiguous" if that is the answer
- [ ] `{ENFORCEMENT_MATRIX}` filled from measurements; template builds; gates green
- [ ] §5 housekeeping applied
- [ ] Any probe whose result contradicts an existing article named explicitly in the report
