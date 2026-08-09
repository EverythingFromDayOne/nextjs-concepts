# nextjs-concepts

Concept articles and symptom-first debugging recipes for **Next.js 16** (App
Router, Cache Components). Fifth in the suite after `angular-concepts`,
`reactjs-concepts`, and `nestjs-concepts`.

**The stale-answer tax.** Almost every Next.js tutorial, Stack Overflow answer,
blog post, and LLM completion was written against Next 13–15, where the
framework cached aggressively by default. Next 16 inverted that: everything is
dynamic by default and you opt *in* with `'use cache'`. Advice that was correct
two years ago silently produces the wrong caching behaviour — and `next dev`
will not tell you.

## Target layout — see `progress.md` for what has landed

```
nextjs-concepts/
├─ docs/
│  ├─ evolution-ledger.md      # mechanism-change spine
│  ├─ templates/               # ARTICLE + RECIPE templates
│  ├─ concepts/                # foundations … ecosystem
│  └─ recipes/                 # symptom-first, by failure domain
├─ demos/next-lab/             # verbatim code-block source of truth
├─ scripts/                    # verify:code-blocks | links | legacy
└─ .github/workflows/verify.yml
```

## Where to start

1. Read [`roadmap.md`](./roadmap.md) §1–2 for the locked baseline and stance.
2. Skim [`docs/evolution-ledger.md`](./docs/evolution-ledger.md) — every article
   cites it.
3. Open [`docs/templates/ARTICLE_TEMPLATE.md`](./docs/templates/ARTICLE_TEMPLATE.md)
   before writing anything.
4. Agents: read [`AGENTS.md`](./AGENTS.md) first, then the bundled Next docs under
   `demos/next-lab/node_modules/next/dist/docs/`.

## Status

Scaffolding only. No article or recipe bodies yet. Track landings in
[`progress.md`](./progress.md).
