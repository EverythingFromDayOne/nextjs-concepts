# nextjs-concepts

An opinionated reference corpus for the Next.js App Router, written against **Next.js 16.3** with Cache Components enabled.

Not a tutorial series. Not interview prep. A set of articles and debugging recipes where every code block is extracted from an application that builds, and every behavioural claim is measured rather than recalled.

---

## Why this exists

Next.js 16 inverted its caching defaults. Before it, the framework cached aggressively and you opted *out*. Now nothing is cached unless you opt *in* with `'use cache'`.

The same code, unchanged, means the opposite thing.

That makes almost every Next.js tutorial, StackOverflow answer, blog post, and LLM completion in existence not merely outdated but **actively wrong** — and the failure is invisible in `next dev`, which is the only place most people would look. We call this the **stale-answer tax**, and every article here carries a mandatory *Then vs now* section that pays it down.

Vercel ships a guardrail against exactly this problem: `next dev` writes an `AGENTS.md` block pointing coding agents at documentation bundled inside `node_modules`, because agents keep writing Next.js 15. A framework that has to warn tooling about its own training data is the strongest argument for a corpus like this one.

---

## The model, in one table

A route is not static or dynamic. A route is a **static shell with holes**, and every piece of data answers one of four questions:

| Answer | Mechanism | Choose it when |
| --- | --- | --- |
| **Cache it** | `'use cache'` + `cacheLife` + `cacheTag` | The value is the same across many requests, and you can name the write that invalidates it |
| **Stream it** | `<Suspense>` | The value differs per request and the user has something else to look at |
| **Block on it** | `export const instant = false` | A shell would be a lie — the page *is* the data |
| **Push it to the client** | `'use client'` | The value doesn't exist on the server: device facts, 60Hz interaction, live connections |

If you can't name the write that invalidates it, the answer is "stream it," not "cache it."

---

## Arriving with the old mental model?

If you learned Next.js as four rendering strategies and four cache layers, here is the translation. Every row links to the article that covers it in full.

| What you were taught | What it is now |
| --- | --- |
| **SSG** — the page is static | The whole route produced a shell and nothing aborted the prerender |
| **SSR** — the page is dynamic | At least one boundary contains a runtime read; everything else still prerenders |
| **ISR** — static, regenerated on a timer | `cacheLife`'s `revalidate` clock, plus shell-then-upgrade for unprerendered params |
| **CSR** — render in the browser | One of four answers, chosen per boundary rather than per app |
| **"Is this route static or dynamic?"** | Wrong question. Ask it per boundary. |
| **Request Memoization** | Still there, still automatic, still per-request |
| **Data Cache** | A storage layer beneath `'use cache'`; no longer an author-facing decision |
| **Full Route Cache** | Replaced by the static shell plus per-scope cache entries |
| **Router Cache** | Alive and now central — `cacheLife`'s `stale` clock drives it |
| **`export const dynamic`** | Deleted. A build error, not a no-op. |
| **`export const revalidate`** | `cacheLife(profile)` inside the cached scope |
| **`unstable_cache`** | `'use cache'`, with compiler-derived keys |
| **`loading.tsx` as the only loading state** | Any `<Suspense>` boundary; shells are extracted from any route |

There is deliberately **no "rendering strategies overview" article** here. The CSR/SSR/SSG/ISR taxonomy is the artifact this corpus argues against; teaching it as a learning path would reproduce the confusion. This table is the bridge instead.

---

## What makes the claims here different

Three rules, enforced by CI rather than by good intentions.

**Code is never hand-written.** Articles are authored as `.md.tpl` templates containing `{EXTRACT:path#symbol}` tokens. A build step pulls the code verbatim out of `demos/next-lab` — a real application that compiles and runs. A verifier re-extracts on every commit and fails if an article and its source have drifted apart.

**Behavioural claims are measured, not recalled.** Error messages, build output, and response captures live in `demos/next-lab/observations/` and are extracted into articles the same way code is. When Next.js changes a message, CI fails rather than the article quietly becoming wrong.

**Corrections are recorded, not silently applied.** Several claims in this corpus were wrong when first written and were changed after measurement contradicted them — that a class instance crossing the client boundary degrades silently (it's rejected), that reading identity inside a cached scope leaks silently (that form is rejected; two others leak), that a coarse `<Suspense>` boundary shows up in TTFB (it doesn't). Each article's *Verification status* footer says what was measured and what was corrected.

Where something couldn't be verified in-session, the article says so rather than sounding confident.

---

## Where to start

**Upgrading from 15, and things broke:** `docs/concepts/migration/fifteen-to-sixteen` — then the recipes under `docs/recipes/caching/`.

**New to the App Router:** `docs/concepts/foundations/thinking-in-the-app-router` — the anchor article. Everything else assumes it.

**You know the App Router but not Cache Components:** `docs/concepts/caching/cache-components-model`.

**Something is broken right now:** `docs/recipes/` — organised by symptom, not by API. Look for what you're seeing, not for what you think is causing it.

---

## Layout

```
docs/
  concepts/          articles, by domain
    foundations/     the model, boundaries, execution phases
    rendering/       shell, streaming, client-side
    caching/         the differentiator — six articles
    routing/         navigation, params, groups, errors
    data/            fetching and runtime data
    mutations/       server functions, forms, invalidation
    auth/            sessions and the network boundary
    performance/     bundle, images, fonts, scripts
    seo/             metadata, sitemaps, structured data
    deployment/      ISR, self-hosting, observability
    ecosystem/       testing, build pipeline, data layer
    migration/       15 → 16, adoption, Pages → App
  recipes/           symptom-first debugging guides
  evolution-ledger.md   every old→new mechanism change, with citations
demos/next-lab/      the application every code block is extracted from
  observations/      recorded build output, errors, and captures
scripts/             the extraction pipeline and CI gates
prompts/             the session prompts that produced this corpus
```

This is the **target layout**. See `progress.md` for what has actually landed — it is kept honest per session and is the only status source worth trusting.

---

## Stack

Next.js 16.3 · React 19.2 · TypeScript 7 · Node 22 · Turbopack · pnpm workspaces · Vitest · Playwright

App Router only. `cacheComponents: true` and `partialPrefetching: true` from day one. Pages Router appears in exactly one place: the migration article.

---

## Related

Part of a suite of standalone learning repositories: `angular-concepts`, `reactjs-concepts`, `nestjs-concepts`, `dsa-concepts`. This repo owns React Server Components for the suite — `reactjs-concepts` deliberately deferred them, on the grounds that the App Router is where they're actually usable.

---

## Licence

Prose under CC BY 4.0. Code under MIT. See `LICENSE`.
