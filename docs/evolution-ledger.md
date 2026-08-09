# Evolution ledger

> Every article's **Then vs now** section must cite at least one row here, or
> explicitly state `No mechanism change — this surface is stable since vN`. An
> article with neither fails review.

This is the repo spine: every place Next.js changed *mechanism* between the
implicit-caching era (13–15) and Cache Components (16+). Articles link back
here. `scripts/verify-legacy-markers.mjs` reads the **Old surface** column as
its banned-token list.

Status legend: `⚪ unwritten` · `🟡 draft` · `🟢 reviewed` · `✅ landed`

| Old surface | New surface | Kind of change | Owning article (planned) | Status | Cite |
| --- | --- | --- | --- | --- | --- |
| `export const dynamic = 'force-dynamic'` | *deleted* — everything is dynamic by default | default inversion | `caching/cache-components-model` | ⚪ unwritten | TODO: verify |
| `export const dynamic = 'force-static'` | `'use cache'` + `cacheLife('max')` | opt-out → opt-in | `caching/use-cache-directive` | ⚪ unwritten | TODO: verify |
| `export const revalidate = N` | `cacheLife(profile)` | route-scope → cache-entry-scope | `caching/cache-lifetimes` | ⚪ unwritten | TODO: verify |
| `export const fetchCache` | *deleted* — fetches inside a `'use cache'` scope are cached | scope inheritance | `caching/use-cache-directive` | ⚪ unwritten | TODO: verify |
| `fetch(url, { cache, next: { revalidate, tags } })` | wrap the fetch in `'use cache'` + `cacheLife` + `cacheTag` | per-call → per-scope | `data/fetching-on-the-server` | ⚪ unwritten | TODO: verify |
| `unstable_cache(fn, keyParts, opts)` | `'use cache'` — compiler derives the key from arguments | manual key → compiler-derived key | `caching/use-cache-directive` | ⚪ unwritten | TODO: verify |
| `unstable_noStore()` / `noStore()` | *deleted* — nothing is cached unless you say so; use `connection()` + `<Suspense>` when work must run per-request | default inversion | `rendering/dynamic-and-connection` | ⚪ unwritten | TODO: verify |
| `cookies()` / `headers()` / `searchParams` opting the whole route dynamic | same APIs, but must sit inside `<Suspense>`; the rest of the page still prerenders | route-level → boundary-level | `rendering/static-shell-and-streaming` | ⚪ unwritten | TODO: verify |
| `experimental.ppr` / `export const experimental_ppr` | removed — PPR is folded into `cacheComponents` | experimental → default architecture | `rendering/partial-prerendering` | ⚪ unwritten | TODO: verify |
| `experimental.dynamicIO` / `experimental.useCache` | `cacheComponents: true` | flag rename + stabilization | `caching/cache-components-model` | ⚪ unwritten | TODO: verify |
| `revalidateTag(tag)` | `revalidateTag(tag, profile)` (profile now **required**); `updateTag(tag)` for read-your-own-writes from a Server Action | SWR vs. immediate split | `mutations/invalidation` | ⚪ unwritten | TODO: verify |
| `dynamicParams` | unsupported under Cache Components — `notFound()` instead | removed config | `routing/dynamic-routes-and-params` | ⚪ unwritten | TODO: verify |
| `generateStaticParams()` returning `[]` | must return ≥1 param so a shell can be validated | contract tightened | `routing/dynamic-routes-and-params` | ⚪ unwritten | TODO: verify |
| `const { slug } = await params` at the top of a page | pass the promise into a `<Suspense>`-wrapped child and await it there | blocking → shell-preserving | `routing/dynamic-routes-and-params` | ⚪ unwritten | TODO: verify |
| `middleware.ts` | `proxy.ts` | renamed to clarify the network boundary | `auth/proxy-and-the-network-boundary` | ⚪ unwritten | TODO: verify |
| `export const runtime = 'edge'` | deprecated; Node.js runtime required for Cache Components | runtime narrowing | `deployment/runtimes` | ⚪ unwritten | TODO: verify |
| unmount-on-navigate | React `<Activity>` in `hidden` mode preserves `useState`, inputs, scroll | lifecycle change with real bug surface | `routing/navigation-and-ui-state` | ⚪ unwritten | TODO: verify |
| eager prefetch of every viewport link | Partial Prefetching — one reusable shell per route | network-shape change | `performance/prefetching` | ⚪ unwritten | TODO: verify |
| Webpack | Turbopack default (dev + build), disk cache on by default | toolchain replacement | `ecosystem/build-pipeline` | ⚪ unwritten | TODO: verify |
| `getServerSideProps` / `getStaticProps` / `getInitialProps` | Server Components + `'use cache'` | paradigm replacement | `migration/pages-to-app` | ⚪ unwritten | TODO: verify |
| *(new, no predecessor)* | `export const instant = false` | new opt-out from instant-navigation validation | `rendering/instant-navigation-validation` | ⚪ unwritten | TODO: verify |
| *(new, no predecessor)* | `'use cache: remote'` / cache handlers | durability across instances & deploys | `deployment/cache-handlers` | ⚪ unwritten | TODO: verify |

## Notes for authors

- Cite column stays `TODO: verify` until a human confirms the claim against
  `demos/next-lab/node_modules/next/dist/docs/` (or the matching migration guide
  page) for the locked baseline.
- Do not add rows you cannot cite.
- Owning-article slugs are **planned** filenames under `docs/concepts/` (or
  `docs/recipes/` / a future `migration/` concept folder) — they are not yet
  written.
