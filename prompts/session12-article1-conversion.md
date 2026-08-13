# Cursor — session 12: article 1 conversion (`foundations/thinking-in-the-app-router`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session12-article1-conversion.md
Model:    channel default
Needs:    pnpm build · python3
```

The lightest session so far. **No new demo code and no new experiments** — every source and capture this template needs already exists. This clears the last hand-written article in the repo.

---

## 1. What this is

Article 1 was written in session 2, before any of it had been measured. Seven sessions later, six of its claims have been measured and three were wrong or imprecise. The replacement template folds all of that in.

| Claim in the session-2 draft | Now |
| --- | --- |
| Verify the shell with view-source | Wrong — a response body shows a completed stream. Read `.next/server/app/<route>.html`. |
| Cache keys derive from arguments **and closures** | Imprecise — ambient state read at execution time cannot be in the key. That's the leak vector. |
| Reading identity in a cached scope leaks silently | Wrong — that form is rejected. Two other forms leak. |
| `instant = false` permits blocking | Incomplete — the shakedown showed it also costs the segment its shell (`ƒ` Dynamic). |
| Sync IO fails, full stop | Incomplete — it is legal inside `'use cache'` and freezes at entry creation. |
| Insights are advisory | Wrong — the same diagnostic is fatal at build. Dev under-reports severity. |

This is a **replacement**, not a patch. The old `.md` is superseded.

## 2. Sources it extracts from — all existing

Verify each is present before building; report anything missing rather than working around it:

```
demos/next-lab/next.config.ts
demos/next-lab/lib/catalog.ts                       (#getProduct)
demos/next-lab/lib/inventory.ts                     (#getLiveStock)
demos/next-lab/app/products/[slug]/page.tsx
demos/next-lab/app/products/[slug]/price-as-of.tsx
demos/next-lab/app/products/[slug]/recently-viewed.tsx
demos/next-lab/app/products/[slug]/add-to-cart.tsx
demos/next-lab/lib/billing-leak-b.ts
demos/next-lab/observations/sync-io-error.txt
demos/next-lab/observations/alerts-minutes-build.txt
demos/next-lab/observations/alerts-seconds-build.txt
demos/next-lab/observations/insight-vs-build-error.txt
demos/next-lab/observations/date-in-cache-scope.txt
```

## 3. Steps

1. Place `prompts/session12/thinking-in-the-app-router.md.tpl` (ships with this prompt).
2. `python3 scripts/build-article.py` on it.
3. **Replace** `docs/concepts/foundations/thinking-in-the-app-router.md` with the built output — move the `.tpl` into `docs/concepts/foundations/` per the staging convention.
4. Delete nothing else; the old article's history stays in git.
5. `pnpm verify` — full chain.

## 4. The number to report

`verify-code-blocks`'s `unsourced-other` count. It was 32 when articles 1 and 2 both carried hand-written code. With article 2 rewritten in session 8 and article 1 rewritten here, **it should be at or near zero.**

If it isn't, tell me what's left and where. Any remaining unsourced block in a non-draft article is either a fence that should be extracted or one that was never code.

Also report the three-bucket link count. The planned-forward warnings should be lower than 16 now that Wave 1 articles exist to link to.

---

## Acceptance

- [ ] All 13 sources verified present before building
- [ ] Template builds; every `{EXTRACT:}` resolves
- [ ] Old `.md` replaced, not patched; `.tpl` staged into `docs/`
- [ ] `unsourced-other` reported — at or near zero, with anything remaining named
- [ ] Link buckets reported
- [ ] Gates green
