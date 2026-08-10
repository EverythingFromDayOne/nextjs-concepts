# Cursor prompt — session 3: Wave 1 demo routes

These are the sources the three drafted articles extract from. Write them verbatim, build, and report observations. **Two of the steps are experiments whose results change the articles** — §7 especially.

Run §1–§6 first, then §7, then §8. Report in the four-block format.

---

## 0. Data-layer decision — deferred, deliberately

Roadmap §7.2 (Drizzle vs Prisma) is **still unapproved**, so Wave 1 demos use a small in-memory data module instead of an ORM.

That is not laziness. Wave 1 is about cache boundaries; the ORM is incidental to every claim these three articles make, and baking in an unapproved choice would make it expensive to reverse. It also keeps CI free of a database service. A real ORM lands in article 44 (`ecosystem/data-layer`), where it is actually the subject.

Consequence: article 6's walkthrough currently shows `db.query.products.findFirst({ where: eq(products.slug, slug) })`. When it converts to `.md.tpl`, the extracted code will read `db.products.findBySlug(slug)` instead. Prose is unaffected — the caching argument doesn't depend on the query syntax.

---

## 1. Config

**`demos/next-lab/next.config.ts`**

```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
}

export default nextConfig
```

If `useTypeScriptCli` is still present from session 2, remove it per the corrections file — it is the default.

## 2. The data layer

**`demos/next-lab/lib/db.ts`**

```ts
/**
 * In-memory data layer for the demo lab.
 *
 * Deliberately not an ORM: Wave 1 is about cache boundaries, the ORM
 * decision (roadmap §7.2) is still open, and CI should not need a database.
 * A real ORM arrives in article 44, where it is the subject rather than
 * scenery.
 *
 * Latency is artificial and load-bearing — without it, streaming holes
 * resolve too fast to observe in a browser.
 */

export type Product = {
  id: string
  slug: string
  name: string
  description: string
  priceCents: number
}

export type Plan = { id: string; name: string; priceCents: number }
export type Usage = { uid: string; requests: number; storageMb: number }
export type Alert = { id: string; level: 'info' | 'warn'; message: string }

const PRODUCTS: Product[] = [
  { id: 'p1', slug: 'aeron-chair', name: 'Aeron Chair', description: 'Mesh task chair.', priceCents: 149500 },
  { id: 'p2', slug: 'standing-desk', name: 'Standing Desk', description: 'Electric sit-stand desk.', priceCents: 89900 },
  { id: 'p3', slug: 'monitor-arm', name: 'Monitor Arm', description: 'Gas-spring single arm.', priceCents: 12900 },
  { id: 'p4', slug: 'keyboard-tray', name: 'Keyboard Tray', description: 'Under-desk sliding tray.', priceCents: 7900 },
]

const PLANS: Plan[] = [
  { id: 'free', name: 'Free', priceCents: 0 },
  { id: 'pro', name: 'Pro', priceCents: 2900 },
  { id: 'team', name: 'Team', priceCents: 9900 },
]

const USAGE: Record<string, Usage> = {
  'user-alice': { uid: 'user-alice', requests: 18_402, storageMb: 512 },
  'user-bob': { uid: 'user-bob', requests: 233, storageMb: 12 },
}

function after<T>(ms: number, value: T): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(value), ms))
}

export const db = {
  products: {
    findBySlug: (slug: string) => after(120, PRODUCTS.find((p) => p.slug === slug) ?? null),
    findByIds: (ids: string[]) => after(120, PRODUCTS.filter((p) => ids.includes(p.id))),
    findMany: () => after(150, PRODUCTS),
    allSlugs: () => after(20, PRODUCTS.map((p) => p.slug)),
  },
  inventory: {
    // Deliberately slow: this is the streamed hole in article 1.
    forSlug: (slug: string) => after(700, (slug.length * 7) % 13),
  },
  plans: {
    findMany: () => after(180, PLANS),
  },
  usage: {
    forUser: (uid: string) => after(400, USAGE[uid] ?? { uid, requests: 0, storageMb: 0 }),
  },
  alerts: {
    findMany: () =>
      after(250, [
        { id: 'a1', level: 'info', message: 'Scheduled maintenance Sunday.' },
      ] satisfies Alert[]),
  },
}

export function formatPrice(cents: number) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(cents / 100)
}
```

## 3. Article 1 — `app/products/[slug]/`

**`demos/next-lab/lib/catalog.ts`**

```ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

export async function getProduct(slug: string) {
  'use cache'
  cacheLife('hours')
  cacheTag(`product:${slug}`)
  return db.products.findBySlug(slug)
}

/**
 * The cache key is derived from the serialized arguments, so `['p1','p2']`
 * and `['p2','p1']` are two different entries for the same result. Sorting
 * before the call is a cache-hit-rate decision, not a style one.
 */
export async function getProductsByIds(ids: string[]) {
  'use cache'
  cacheLife('hours')
  return db.products.findByIds([...ids].sort())
}

export async function getAllProducts() {
  'use cache'
  cacheLife('hours')
  cacheTag('products')
  return db.products.findMany()
}

export async function getPrerenderedSlugs() {
  return db.products.allSlugs()
}
```

**`demos/next-lab/lib/inventory.ts`**

```ts
import { db } from './db'

/**
 * No 'use cache', deliberately. Inventory that is thirty seconds stale
 * sells things we do not have. This is the "stream it" answer.
 */
export async function getLiveStock(slug: string) {
  return db.inventory.forSlug(slug)
}
```

**`demos/next-lab/app/products/[slug]/skeletons.tsx`**

```tsx
export function ProductHeaderSkeleton() {
  return <header aria-busy="true"><h1>Loading product…</h1></header>
}

export function InventorySkeleton() {
  return <p aria-busy="true">Checking inventory…</p>
}

export function RecentlyViewedSkeleton() {
  return <section aria-busy="true"><h2>Recently viewed</h2></section>
}
```

**`demos/next-lab/app/products/[slug]/inventory.tsx`**

```tsx
import { getLiveStock } from '@/lib/inventory'

export async function Inventory({
  params,
}: Pick<PageProps<'/products/[slug]'>, 'params'>) {
  const { slug } = await params
  const stock = await getLiveStock(slug)

  return stock > 0 ? <p>{stock} in stock</p> : <p>Out of stock</p>
}
```

**`demos/next-lab/app/products/[slug]/recently-viewed.tsx`**

```tsx
import { cookies } from 'next/headers'
import { getProductsByIds } from '@/lib/catalog'

export async function RecentlyViewed() {
  // The identity read happens HERE, outside any cached scope. The ids are
  // then passed to getProductsByIds as an argument, so the lookup can be
  // cached without the cache knowing who asked.
  const raw = (await cookies()).get('recently-viewed')?.value
  const ids = raw ? (JSON.parse(raw) as string[]) : []
  if (ids.length === 0) return null

  const products = await getProductsByIds(ids)
  return (
    <section>
      <h2>Recently viewed</h2>
      <ul>{products.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
    </section>
  )
}
```

**`demos/next-lab/app/products/[slug]/price-as-of.tsx`**

```tsx
import { connection } from 'next/server'

export async function PriceAsOf() {
  // Without this line the build fails: new Date() cannot suspend, so the
  // prerender would bake a build-time clock into a static artifact.
  await connection()
  return <p>Prices as of <time>{new Date().toLocaleTimeString('en-US')}</time></p>
}
```

**`demos/next-lab/app/products/[slug]/add-to-cart.tsx`**

```tsx
'use client'

// client: owns the quantity input's local state
import { useState } from 'react'
import { addToCart } from './actions'

export function AddToCart({ productId }: { productId: string }) {
  const [qty, setQty] = useState(1)

  return (
    <form action={addToCart}>
      <input type="hidden" name="productId" value={productId} />
      <input
        type="number"
        name="qty"
        min={1}
        value={qty}
        onChange={(e) => setQty(Number(e.target.value))}
      />
      <button type="submit">Add to cart</button>
    </form>
  )
}
```

**`demos/next-lab/app/products/[slug]/actions.ts`**

```ts
'use server'

export async function addToCart(formData: FormData) {
  const productId = String(formData.get('productId') ?? '')
  const qty = Number(formData.get('qty') ?? 1)
  if (!productId || qty < 1) return
  // A real implementation authorizes here — a Server Function is a public
  // endpoint, and the UI that called it is not the authorization.
  console.log('[demo] add to cart', { productId, qty })
}
```

**`demos/next-lab/app/products/[slug]/page.tsx`**

```tsx
import { Suspense } from 'react'
import { notFound } from 'next/navigation'
import { getProduct, getPrerenderedSlugs } from '@/lib/catalog'
import { formatPrice } from '@/lib/db'
import { AddToCart } from './add-to-cart'
import { Inventory } from './inventory'
import { RecentlyViewed } from './recently-viewed'
import { PriceAsOf } from './price-as-of'
import {
  ProductHeaderSkeleton,
  InventorySkeleton,
  RecentlyViewedSkeleton,
} from './skeletons'

export async function generateStaticParams() {
  const slugs = await getPrerenderedSlugs()
  // Deliberately a subset: the remaining slug exercises shell-then-upgrade.
  return slugs.slice(0, 3).map((slug) => ({ slug }))
}

// Note: this component is NOT async and awaits nothing. Its entire job is
// to declare where the shell ends and the holes begin.
export default function Page({ params }: PageProps<'/products/[slug]'>) {
  return (
    <main>
      <Suspense fallback={<ProductHeaderSkeleton />}>
        <ProductHeader params={params} />
      </Suspense>

      <Suspense fallback={<InventorySkeleton />}>
        <Inventory params={params} />
      </Suspense>

      <Suspense fallback={null}>
        <PriceAsOf />
      </Suspense>

      <Suspense fallback={<RecentlyViewedSkeleton />}>
        <RecentlyViewed />
      </Suspense>
    </main>
  )
}

async function ProductHeader({
  params,
}: Pick<PageProps<'/products/[slug]'>, 'params'>) {
  // params is awaited HERE, inside the boundary, not at the top of Page.
  const { slug } = await params
  const product = await getProduct(slug)
  if (!product) notFound()

  return (
    <header>
      <h1>{product.name}</h1>
      <p>{product.description}</p>
      <strong>{formatPrice(product.priceCents)}</strong>
      <AddToCart productId={product.id} />
    </header>
  )
}
```

## 4. Article 2 — `app/catalog/`

Stages 1–3 go in `_stages/`, a **private folder** — the underscore keeps Next from routing them while `tsc` still type-checks them. `page.tsx` is stage 4.

**`demos/next-lab/app/catalog/product-row.tsx`**

```tsx
import type { Product } from '@/lib/db'
import { formatPrice } from '@/lib/db'

// Server Component. Passed into FilterShell as children, never imported
// by it — which is why it stays out of the client bundle.
export function ProductRow({ product }: { product: Product }) {
  return (
    <li>
      {product.name} — {formatPrice(product.priceCents)}
    </li>
  )
}
```

**`demos/next-lab/app/catalog/filter-shell.tsx`**

```tsx
'use client'

// client: owns the filter text state
import { createContext, useContext, useState } from 'react'

const FilterContext = createContext('')
export const useFilter = () => useContext(FilterContext)

export function FilterShell({ children }: { children: React.ReactNode }) {
  const [filter, setFilter] = useState('')

  return (
    <FilterContext.Provider value={filter}>
      <input
        value={filter}
        placeholder="Filter…"
        onChange={(e) => setFilter(e.target.value)}
      />
      {children}
    </FilterContext.Provider>
  )
}
```

**`demos/next-lab/app/catalog/filterable-list.tsx`**

```tsx
'use client'

// client: owns filter state AND unwraps a streamed promise
import { use, useState } from 'react'
import type { Product } from '@/lib/db'
import { formatPrice } from '@/lib/db'

export function FilterableList({ products }: { products: Promise<Product[]> }) {
  const list = use(products)
  const [filter, setFilter] = useState('')
  const visible = list.filter((p) =>
    p.name.toLowerCase().includes(filter.toLowerCase())
  )

  return (
    <>
      <input
        value={filter}
        placeholder="Filter…"
        onChange={(e) => setFilter(e.target.value)}
      />
      <ul>
        {visible.map((p) => (
          <li key={p.id}>{p.name} — {formatPrice(p.priceCents)}</li>
        ))}
      </ul>
    </>
  )
}
```

**`demos/next-lab/app/catalog/page.tsx`** — stage 4

```tsx
import { Suspense } from 'react'
import { getAllProducts } from '@/lib/catalog'
import { FilterableList } from './filterable-list'

export default function CatalogPage() {
  // Not awaited. The promise crosses the client boundary and is unwrapped
  // with use() on the other side, so the page never blocks.
  const productsPromise = getAllProducts()

  return (
    <Suspense fallback={<p aria-busy="true">Loading catalog…</p>}>
      <FilterableList products={productsPromise} />
    </Suspense>
  )
}
```

**`demos/next-lab/app/catalog/_stages/stage1-page.tsx`**

```tsx
'use client'

// STAGE 1 — the version most people write first, preserved to be measured
// against. Four costs: whole subtree in the client graph, data loads after
// hydration, an API route that exists only for this page, and an empty shell.
import { useEffect, useState } from 'react'
import type { Product } from '@/lib/db'

export function Stage1CatalogPage() {
  const [products, setProducts] = useState<Product[]>([])
  const [filter, setFilter] = useState('')

  useEffect(() => {
    fetch('/api/products')
      .then((r) => r.json())
      .then(setProducts)
  }, [])

  const visible = products.filter((p) => p.name.includes(filter))

  return (
    <>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      <ul>{visible.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
    </>
  )
}
```

**`demos/next-lab/app/catalog/_stages/stage2-page.tsx`**

```tsx
// STAGE 2 — server data, client filter. Waterfall and API route gone, but
// every product now crosses the boundary as a serialized prop.
import { getAllProducts } from '@/lib/catalog'
import { Stage2List } from './stage2-list'

export async function Stage2CatalogPage() {
  const products = await getAllProducts()
  return <Stage2List products={products} />
}
```

**`demos/next-lab/app/catalog/_stages/stage2-list.tsx`**

```tsx
'use client'

import { useState } from 'react'
import type { Product } from '@/lib/db'

export function Stage2List({ products }: { products: Product[] }) {
  const [filter, setFilter] = useState('')
  const visible = products.filter((p) => p.name.includes(filter))

  return (
    <>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      <ul>{visible.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
    </>
  )
}
```

**`demos/next-lab/app/catalog/_stages/stage3-page.tsx`**

```tsx
// STAGE 3 — the slot. Rows are rendered on the server and passed through
// the client boundary as children, so they are never bundled.
//
// The trade this makes: the client no longer has the data, so the filter
// cannot re-filter locally. If instant local filtering is required,
// stage 2 is correct and the prop cost is the price.
import { getAllProducts } from '@/lib/catalog'
import { FilterShell } from '../filter-shell'
import { ProductRow } from '../product-row'

export async function Stage3CatalogPage() {
  const products = await getAllProducts()

  return (
    <FilterShell>
      <ul>
        {products.map((p) => <ProductRow key={p.id} product={p} />)}
      </ul>
    </FilterShell>
  )
}
```

## 5. Article 6 — `app/dashboard/`

**`demos/next-lab/lib/billing.ts`**

```ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

export async function getPlans() {
  'use cache'
  cacheLife('days')
  cacheTag('plans')
  return db.plans.findMany()
}

// uid is an ARGUMENT. It is therefore in the compiler-derived key, which
// is the entire difference between a per-user entry and a shared one.
export async function getUsage(uid: string) {
  'use cache'
  cacheLife('minutes')
  cacheTag(`usage:${uid}`)
  return db.usage.forUser(uid)
}
```

**`demos/next-lab/lib/status.ts`**

```ts
import { cacheLife } from 'next/cache'
import { db } from './db'

/**
 * No cacheTag, deliberately: nothing in our system can invalidate a third
 * party's status feed, so a tag would be decoration. Time is the only
 * honest lever.
 *
 * cacheLife('minutes') keeps this in the prerender. 'seconds' would not —
 * its one-minute expire falls under the exclusion threshold.
 */
export async function getAlerts() {
  'use cache'
  cacheLife('minutes')
  return db.alerts.findMany()
}
```

**`demos/next-lab/app/dashboard/parts.tsx`**

```tsx
import type { Alert, Plan, Usage } from '@/lib/db'
import { formatPrice } from '@/lib/db'

export function PlanTable({ plans }: { plans: Plan[] }) {
  return (
    <table>
      <tbody>
        {plans.map((p) => (
          <tr key={p.id}><td>{p.name}</td><td>{formatPrice(p.priceCents)}</td></tr>
        ))}
      </tbody>
    </table>
  )
}

export function UsageChart({ usage }: { usage: Usage }) {
  return (
    <p data-uid={usage.uid}>
      {usage.requests.toLocaleString('en-US')} requests · {usage.storageMb} MB
    </p>
  )
}

export function AlertBanner({ alerts }: { alerts: Alert[] }) {
  if (alerts.length === 0) return null
  return <ul>{alerts.map((a) => <li key={a.id}>{a.message}</li>)}</ul>
}

export function PlanTableSkeleton() {
  return <p aria-busy="true">Loading plans…</p>
}

export function UsageSkeleton() {
  return <p aria-busy="true">Loading usage…</p>
}
```

**`demos/next-lab/app/dashboard/page.tsx`**

```tsx
import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { connection } from 'next/server'
import { getPlans, getUsage } from '@/lib/billing'
import { getAlerts } from '@/lib/status'
import {
  PlanTable, UsageChart, AlertBanner, PlanTableSkeleton, UsageSkeleton,
} from './parts'

export default function DashboardPage() {
  return (
    <main>
      <Suspense fallback={<PlanTableSkeleton />}><Plans /></Suspense>
      <Suspense fallback={<UsageSkeleton />}><Usage /></Suspense>
      <Suspense fallback={null}><Alerts /></Suspense>
      <Suspense fallback={null}><LastRefreshed /></Suspense>
    </main>
  )
}

async function Plans() {
  return <PlanTable plans={await getPlans()} />
}

async function Usage() {
  // Runtime read, outside the cached scope. The value is passed in.
  const uid = (await cookies()).get('uid')?.value
  if (!uid) return <p>Sign in to see usage.</p>
  return <UsageChart usage={await getUsage(uid)} />
}

async function Alerts() {
  return <AlertBanner alerts={await getAlerts()} />
}

async function LastRefreshed() {
  await connection()
  return <time>{new Date().toLocaleTimeString('en-US')}</time>
}
```

## 6. The Next-15 "before" state — must never compile

**`demos/next-lab/legacy/dashboard-page.next15.tsx`**

Add `"legacy"` to the demo's `tsconfig.json` `exclude` array. This file uses APIs that are build errors under Cache Components; it exists only to be extracted into article 6's Step 0.

```tsx
// legacy: Next <16 implicit-caching model — see docs/evolution-ledger.md
// NOT COMPILED. Excluded from tsconfig. Extraction target only.
export const dynamic = 'force-dynamic'
export const revalidate = 60

import { cookies } from 'next/headers'
import { unstable_cache } from 'next/cache'

const getPlans = unstable_cache(
  async () => db.plans.findMany(),
  ['plans'],
  { revalidate: 3600, tags: ['plans'] }
)

export default async function DashboardPage() {
  const uid = (await cookies()).get('uid')?.value
  const [plans, usage, alerts] = await Promise.all([
    getPlans(),
    db.usage.forUser(uid),
    fetch('https://status.example.com/alerts').then((r) => r.json()),
  ])

  return (
    <main>
      <PlanTable plans={plans} />
      <UsageChart usage={usage} />
      <AlertBanner alerts={alerts} />
      <LastRefreshed at={new Date()} />
    </main>
  )
}
```

Confirm `verify-legacy-markers` passes on this once extracted — the marker comment is on line 1 for exactly that reason.

---

## 7. EXPERIMENT — is the cross-user leak actually reachable?

**This is the most important step in the session. A claim in article 6 may be wrong, and I would rather find out here than after eleven more articles cite it.**

Article 6 (mistake #3, exercise 3) and planned recipe #2 all assert that reading identity inside a `'use cache'` scope silently leaks one user's data to another. But Cache Components forbids runtime APIs inside cached scopes — that is the stated reason `'use cache: private'` exists. **If Next errors on the naive form, the leak is not reachable that way and the articles are overclaiming.**

Test three candidate vectors. For each, record: does it build? does it run? does it leak?

**Vector A — `cookies()` directly inside a cached scope.** Create `demos/next-lab/lib/billing-leak-a.ts`:

```ts
import { cacheLife } from 'next/cache'
import { cookies } from 'next/headers'
import { db } from './db'

export async function getDashboardLeakA() {
  'use cache'
  cacheLife('minutes')
  const uid = (await cookies()).get('uid')?.value ?? 'anonymous'
  return db.usage.forUser(uid)
}
```

Expected: **build error.** Record the exact message.

**Vector B — identity captured from a module-level variable.** `lib/billing-leak-b.ts`:

```ts
import { cacheLife } from 'next/cache'
import { db } from './db'

let lastSeenUid = 'anonymous' // set by an uncached caller before the call

export function rememberUid(uid: string) {
  lastSeenUid = uid
}

export async function getDashboardLeakB() {
  'use cache'
  cacheLife('minutes')
  return db.usage.forUser(lastSeenUid)
}
```

Expected: builds, and leaks — the key derives from arguments and closures, and `lastSeenUid` is neither at call time. **This is my hypothesis for the real vector.**

**Vector C — a key too coarse to distinguish users.** `lib/billing-leak-c.ts`:

```ts
import { cacheLife } from 'next/cache'
import { db } from './db'

// The argument is in the key — but every signed-in user passes the same one.
export async function getDashboardLeakC(scope: 'signed-in' | 'anonymous') {
  'use cache'
  cacheLife('minutes')
  const uid = scope === 'signed-in' ? 'user-alice' : 'anonymous'
  return db.usage.forUser(uid)
}
```

Wire each behind a route — `app/leak-a/page.tsx`, `leak-b`, `leak-c` — that reads the `uid` cookie in an uncached component and calls the corresponding function. Then:

```bash
pnpm build && pnpm start
curl -s -H 'Cookie: uid=user-alice' http://localhost:3000/leak-b | grep data-uid
curl -s -H 'Cookie: uid=user-bob'   http://localhost:3000/leak-b | grep data-uid
```

`UsageChart` renders `data-uid`, so the leak is visible in the HTML: if Bob's request returns `data-uid="user-alice"`, the vector is real.

**Report a table:** vector / builds? / runs? / leaks? / exact error or observed output. Do not fix anything. **Do not delete these files** — if a vector is real, it becomes the demo source for recipe #2.

## 8. Build, observe, report

```bash
pnpm --filter next-lab build
pnpm --filter next-lab start
```

Record, verbatim where possible:

1. **The route table from `next build`** — full output. Which of `/products/[slug]`, `/catalog`, `/dashboard` are prerendered, and how each is annotated.
2. **`/products/aeron-chair` initial HTML** (`curl`, not DevTools): are name/price/description present? Is "Checking inventory…" present? Is the timestamp absent?
3. **`/products/keyboard-tray`** — the slug `generateStaticParams` did *not* return. Shell first, then content?
4. **Delete `await connection()` from `price-as-of.tsx`, rebuild.** Record the exact error text, then restore. This is the sync-IO claim in articles 1 and 6.
5. **Flip `getAlerts` to `cacheLife('seconds')`, rebuild.** Do the alerts leave the prerendered HTML for `/dashboard`? Record both build outputs, then restore. This is the lifetime-affects-placement claim.
6. **First Load JS for `/catalog`.** Note that stages 1–3 are not routes, so they will not appear in the table — say so rather than reporting a missing number.
7. **Any validation insight** in the dev-server log for these three routes. A route can return 200 and still be flagged.

Items 4, 5, and 7 are the ones that turn authored claims into measured ones. Report what you saw, not what the articles predicted.

---

## Acceptance

- [ ] All files written verbatim; `pnpm build` green
- [ ] `legacy/` excluded in `tsconfig.json`; nothing in it compiled
- [ ] §7 vector table complete with exact errors/output; leak files retained
- [ ] §8 items 1–7 recorded, including the two revert-after-testing steps
- [ ] Discrepancies between observed behavior and article claims listed explicitly in the report — **that list is the point of this session**
