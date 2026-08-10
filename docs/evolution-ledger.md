# Evolution ledger

> Every article's **Then vs now** section must cite at least one row here, or
> explicitly state `No mechanism change — this surface is stable since vN`. An
> article with neither fails review.

This is the repo spine: every place Next.js changed *mechanism* between the
implicit-caching era (13–15) and Cache Components (16+). Articles link back
here. `scripts/verify-legacy-markers.mjs` reads banned tokens from rows whose
**Ban** column is `yes` — not from every Old-surface cell.

Status legend: `⚪ unwritten` · `🟡 draft` · `🟢 reviewed` · `✅ landed`

**Ban column:** `yes` = removed/renamed surface; appearances outside an allowed
section fail CI. `no` = API still exists (semantics changed) or there is no old
code token to ban — do not ban the live name.

Cite paths are relative to `demos/next-lab/node_modules/next/dist/docs/`,
verified against the locked `next@16.3.0` bundle on 2026-08-10.

| Old surface | New surface | Kind of change | Ban | Owning article (planned) | Status | Cite |
| --- | --- | --- | --- | --- | --- | --- |
| `export const dynamic = 'force-dynamic'` | *deleted* — everything is dynamic by default | default inversion | yes | `caching/cache-components-model` | 🟢 drafted | `01-app/02-guides/migrating-to-cache-components.md` |
| `export const dynamic = 'force-static'` | `'use cache'` + `cacheLife('max')` | opt-out → opt-in | yes | `caching/use-cache-directive` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `export const revalidate = N` | `cacheLife(profile)` | route-scope → cache-entry-scope | yes | `caching/cache-lifetimes` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `export const fetchCache` | *deleted* — fetches inside a `'use cache'` scope are cached | scope inheritance | yes | `caching/use-cache-directive` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `fetch(url, { cache, next: { revalidate, tags } })` | wrap the fetch in `'use cache'` + `cacheLife` + `cacheTag` | per-call → per-scope | yes | `data/fetching-on-the-server` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `unstable_cache(fn, keyParts, opts)` | `'use cache'` — compiler derives the key from arguments | manual key → compiler-derived key | yes | `caching/use-cache-directive` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `unstable_noStore()` / `noStore()` | *deleted* — nothing is cached unless you say so; use `connection()` + `<Suspense>` when work must run per-request | default inversion | yes | `foundations/build-time-request-time-and-the-client` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `cookies()` / `headers()` / `searchParams` opting the whole route dynamic | same APIs, but must sit inside `<Suspense>`; the rest of the page still prerenders | route-level → boundary-level (API still exists, semantics changed) | no | `rendering/static-shell-and-streaming` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `experimental.ppr` / `export const experimental_ppr` | removed — PPR is folded into `cacheComponents` | experimental → default architecture | yes | `rendering/static-shell-and-streaming` | ⚪ unwritten | `01-app/03-api-reference/05-config/01-next-config-js/cacheComponents.md` |
| `experimental.dynamicIO` / `experimental.useCache` | `cacheComponents: true` | flag rename + stabilization | yes | `caching/cache-components-model` | 🟢 drafted | `01-app/02-guides/upgrading/version-16.md` |
| `revalidateTag(tag)` | `revalidateTag(tag, profile)` (profile now **required**); `updateTag(tag)` for read-your-own-writes from a Server Action | SWR vs. immediate split (API still exists, signature tightened) | no | `caching/tags-and-invalidation` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `dynamicParams` | unsupported under Cache Components — `notFound()` instead | removed config | yes | `routing/dynamic-routes-and-params` | ⚪ unwritten | `01-app/03-api-reference/03-file-conventions/02-route-segment-config/dynamicParams.md` |
| `generateStaticParams()` returning `[]` | must return ≥1 param so a shell can be validated | contract tightened (API still exists) | no | `routing/dynamic-routes-and-params` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `const { slug } = await params` at the top of a page | pass the promise into a `<Suspense>`-wrapped child and await it there | blocking → shell-preserving (API still exists; placement changed) | no | `routing/dynamic-routes-and-params` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| `middleware.ts` | `proxy.ts` | renamed to clarify the network boundary | yes | `auth/proxy-and-the-network-boundary` | ⚪ unwritten | `01-app/03-api-reference/03-file-conventions/middleware.md` |
| `export const runtime = 'edge'` | deprecated; Node.js runtime required for Cache Components | runtime narrowing | yes | `deployment/self-hosting-adapters-and-cache-handlers` | ⚪ unwritten | `01-app/02-guides/migrating-to-cache-components.md` |
| unmount-on-navigate | React `<Activity>` in `hidden` mode preserves `useState`, inputs, scroll | lifecycle change with real bug surface | no | `routing/navigation-and-ui-state` | ⚪ unwritten | `01-app/02-guides/preserving-ui-state.md` |
| eager prefetch of every viewport link | Partial Prefetching — one reusable shell per route | network-shape change | no | `routing/instant-navigation-and-prefetching` | ⚪ unwritten | `01-app/02-guides/adopting-partial-prefetching.md` |
| Webpack | Turbopack default (dev + build), disk cache on by default | toolchain replacement (Webpack still exists; not the default) | no | `ecosystem/build-pipeline` | ⚪ unwritten | `01-app/02-guides/upgrading/version-16.md` |
| `getServerSideProps` / `getStaticProps` / `getInitialProps` | Server Components + `'use cache'` | paradigm replacement | yes | `migration/pages-to-app` | ⚪ unwritten | `01-app/02-guides/incremental-static-regeneration-cache-components.md` |
| *(new, no predecessor)* | `export const instant = false` | new opt-out from instant-navigation validation | no | `routing/instant-navigation-and-prefetching` | ⚪ unwritten | `01-app/03-api-reference/03-file-conventions/02-route-segment-config/instant.md` |
| *(new, no predecessor)* | `'use cache: remote'` / cache handlers | durability across instances & deploys | no | `caching/private-and-remote-caches` | ⚪ unwritten | `01-app/03-api-reference/01-directives/use-cache-remote.md` |

## Notes for authors

- Cite column paths are version-matched to the locked Next.js baseline.
- Do not add rows you cannot cite — mark `UNVERIFIED` instead of guessing.
- Owning-article slugs follow `roadmap.md` §3 (revision 2, 47 articles).
- Set **Ban** when you add a row: `yes` only if the Old surface must not appear as live guidance.
- **Row nuance (dynamicParams):** “unsupported under Cache Components” is explicit in `dynamicParams.md`. The ledger’s “`notFound()` instead” is the practical replacement pattern for missing params, not a documented 1:1 rename of `dynamicParams: false`.
