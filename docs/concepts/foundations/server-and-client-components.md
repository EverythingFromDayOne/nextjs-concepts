---
article_id: server-and-client-components
concept_folder: foundations
wave: 1
related:
  - foundations/thinking-in-the-app-router
  - foundations/rules-of-the-server-boundary
  - performance/the-client-bundle
  - mutations/server-functions
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-09
status: draft
---

# Server and Client Components

> **Lead with this.** `'use client'` does not mean "runs on the client." It means **"this module is an entry point into the client module graph."** Two consequences follow, and between them they explain every rule in this article: the directive spreads through `import`, never through JSX children; and Client Components still render on the server, then hydrate. If you have been reading the directive as "make this interactive," swap in "add this module and everything it imports to the browser bundle" and most of the confusion evaporates.

This is the article [`reactjs-concepts`](../../../../reactjs-concepts/docs/roadmap.md) deferred when it fenced RSC as "coverage happens via Next.js App Router, since that's where RSC is actually usable in production." This is that coverage.

---

## What it is

Your app has **one source tree and two module graphs**.

The **server graph** is everything reachable from the route tree without crossing a `'use client'` file. It runs on the server only. It never ships to the browser. It can touch the database, read secrets, and `await` freely.

The **client graph** starts at every file carrying `'use client'` and extends through everything those files import. It is bundled, shipped, parsed, and executed in the browser — and, first, executed on the server to produce initial HTML.

The directive is the seam between the two graphs. It is placed on a *file*, before any imports, and the exports of that file become entry points.

```tsx
'use client'

import { useState } from 'react'

export function QuantityPicker({ max }: { max: number }) {
  const [qty, setQty] = useState(1)
  // ...
}
```

You do **not** repeat the directive in every file underneath. A file imported by a Client Component is already in the client graph — the directive would be redundant. You add it only where a Server Component renders directly into client-land.

### The two things everyone gets wrong

**1. `'use client'` is not "client-only."** Client Components are server-rendered to HTML on the first request, exactly like every React component in every SSR framework since 2016, and *then* hydrated. The directive controls **where the module lives**, not **where it executes**. Truly client-only behavior — reading `window`, measuring the DOM — still needs an effect or a client-only dynamic import.

**2. The directive spreads through `import`, not through JSX.** This is the mechanical fact that makes composition work, and it is worth stating precisely:

- A component you **import** into a Client Component joins the client graph. It gets bundled. If it was a Server Component doing database work, it will now break.
- A component you receive as **`children`** (or any other element prop) does *not* join the client graph. It was rendered on the server and arrives as output — the Client Component only decides *where to put it*, never *how to produce it*.

So a Server Component can render inside a Client Component. It just cannot be imported by one.

---

## How it works under the hood

### The RSC payload is not HTML

When the server renders a route, it produces two things: streamed HTML for first paint, and an **RSC payload** — a serialized description of the rendered tree.

In that payload, Server Components have already collapsed into their output: elements, text, attributes. There is nothing left to run. Client Components are different. They appear as a **client reference**: a module id, an export name, and the props they were given.

```
// conceptually, one node in the payload
["$", "@42#QuantityPicker", null, { "max": 10 }]
      └─ module id + export        └─ serialized props
```

The browser runtime reads that reference, resolves module 42 from the client bundle, and mounts `QuantityPicker` with those props.

Three real consequences fall directly out of this representation:

**Props are serialized into the payload on every render.** They are not a one-time hydration cost. Every navigation that re-renders that boundary re-serializes them. Passing an entire 400-row dataset into a Client Component to render a table means shipping that dataset in the payload each time — which is why "the page feels heavy and I don't know why" so often traces back to prop size rather than bundle size.

**Serializability is not a style rule; it is a consequence of the wire format.** A prop must have a representation in the payload. Primitives, plain objects and arrays, `Date`, `Map`, `Set`, typed arrays, `FormData`, JSX elements, and Promises all do. A function does not — there is no way to send a closure. Class instances do not survive either: the fields might serialize, but the prototype and its methods will not, so what arrives is a shape that looks right and answers `undefined` to every method call.

**Server Functions are the single exception, and for a principled reason.** A `'use server'` function *does* have a wire representation: it is a reference to an addressable endpoint, exactly like a client reference is a reference to an addressable module. That is why the one kind of function that may cross the boundary is the one kind that is really an id in disguise.

```tsx
// ❌ no wire representation — closure cannot be sent
<Button onSubmit={() => save(id)} />

// ✅ a reference to a server endpoint
<Button action={saveProduct} />   // saveProduct is 'use server'
```

Related and easy to trip over: you may pass a rendered **element**, but not a component **function**.

```tsx
// ❌ this is a function
<Modal content={CartContents} />

// ✅ this is already-rendered output
<Modal content={<CartContents />} />
<Modal><CartContents /></Modal>
```

### Server Components have no client lifecycle

A Server Component is not "a component that runs once." It is a component that **produces payload**. It has no state, no effects, no event handlers, and no presence in the browser at all. Asking "why doesn't my `useEffect` run in this Server Component" is asking why a function that finished executing on another machine has a lifecycle.

The corollary matters more than the rule: **re-rendering a Server Component is a network round trip.** In client React, a re-render is a function call you can afford to be casual about. Here it is a request that returns a fresh payload which React reconciles into the existing tree. Anything you would have solved with a cheap re-render needs a client boundary or a cache entry instead.

### Where the boundary sits relative to the shell

This is where the Cache Components model from [`thinking-in-the-app-router`](./thinking-in-the-app-router.md) meets the client boundary, and it is the part that is genuinely new.

A Client Component lands **in the static shell** if its props are computable during the prerender pass. `<QuantityPicker max={10} />` prerenders fine. `<QuantityPicker max={await getStock(slug)} />` does not, because the prop is request-shaped — the abort happens while computing the prop, above the client boundary entirely.

The same logic explains a rule that otherwise looks like an arbitrary Next.js quirk: client hooks that read the route **suspend during prerendering** when the value isn't knowable yet. `usePathname`, `useParams`, `useSelectedLayoutSegment`, and `useSelectedLayoutSegments` suspend under a route with dynamic params. `useSearchParams` always suspends, because search params are only ever known at request time.

They suspend *wherever they sit* — including inside a nav or breadcrumb in a shared layout, which is how a single `useSearchParams` in a header can cost you the shell for every route beneath it. The fix is the same as everywhere else in this model: push the read down to the smallest leaf and wrap that leaf in `<Suspense>`.

### The blurred edge: calling cached server functions from the client

One boundary that used to be sharp is now deliberately porous. When a cache directive sits at the **top of a file**, that file's exported functions can be imported into a Client Component and called directly. They execute on the server and return their result — behaving much like a Server Function.

```ts
// lib/search.ts
'use cache'

export async function searchProducts(query: string) {
  return db.search(query)
}
```

```tsx
'use client'
import { searchProducts } from '@/lib/search'   // legal; runs on the server
```

Useful, and worth being deliberate about: the docs' own preference is still to call cached functions on the server and pass results down as props. Reach for the direct-call form when the *trigger* is genuinely a client interaction, not to avoid thinking about composition.

---

## Basic usage

The default is Server. You opt into Client, at a leaf, for a stated reason.

```tsx
// app/products/page.tsx — Server Component (no directive)
import { getProducts } from '@/lib/catalog'
import { SortControl } from './sort-control'

export default async function ProductsPage() {
  const products = await getProducts()

  return (
    <section>
      <SortControl />           {/* client leaf */}
      <ul>
        {products.map((p) => <li key={p.id}>{p.name}</li>)}
      </ul>
    </section>
  )
}
```

```tsx
// app/products/sort-control.tsx — Client Component
'use client'

import { useState } from 'react'

export function SortControl() {
  const [order, setOrder] = useState<'asc' | 'desc'>('asc')
  return (
    <button onClick={() => setOrder(order === 'asc' ? 'desc' : 'asc')}>
      Sort {order}
    </button>
  )
}
```

The list stays on the server. Only the button ships.

---

## Walkthrough — moving a boundary down, in four stages

We will start with the version most people write first, and fix it in stages. The feature: a product list with a client-side text filter.

### Stage 1 — the version that looks reasonable and is wrong

```tsx
// app/catalog/page.tsx
'use client'

import { useState, useEffect } from 'react'

export default function CatalogPage() {
  const [products, setProducts] = useState([])
  const [filter, setFilter] = useState('')

  useEffect(() => {
    fetch('/api/products').then((r) => r.json()).then(setProducts)
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

Four costs, none of them obvious from reading it:

1. The directive is on the page, so the **entire subtree** is in the client graph.
2. Data now loads *after* hydration — a waterfall the server didn't have.
3. You needed a `/api/products` route that exists only to serve your own page.
4. The shell contains an empty list. There is nothing useful to prerender.

### Stage 2 — server data, client filter

Split the responsibility. The server owns the data; the client owns exactly one piece of state.

```tsx
// app/catalog/page.tsx — Server Component again
import { getProducts } from '@/lib/catalog'
import { FilterableList } from './filterable-list'

export default async function CatalogPage() {
  const products = await getProducts()
  return <FilterableList products={products} />
}
```

```tsx
// app/catalog/filterable-list.tsx
'use client'

import { useState } from 'react'
import type { Product } from '@/lib/schema'

export function FilterableList({ products }: { products: Product[] }) {
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

The waterfall is gone and the API route is gone. But we have traded one problem for another: **every product now crosses the boundary as a prop**, serialized into the payload. At 40 products that is fine. At 4,000 it is the dominant cost on the page, and it will not show up in a bundle-size report.

### Stage 3 — the slot, so the rows stay on the server

The rows are not interactive. Only the input is. So let the client component own the *state and the layout*, and receive the rows as already-rendered output.

```tsx
// app/catalog/filter-shell.tsx
'use client'

import { useState, createContext, useContext } from 'react'

const FilterContext = createContext('')
export const useFilter = () => useContext(FilterContext)

export function FilterShell({ children }: { children: React.ReactNode }) {
  const [filter, setFilter] = useState('')
  return (
    <FilterContext.Provider value={filter}>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      {children}
    </FilterContext.Provider>
  )
}
```

```tsx
// app/catalog/page.tsx
import { getProducts } from '@/lib/catalog'
import { FilterShell } from './filter-shell'
import { ProductRow } from './product-row'

export default async function CatalogPage() {
  const products = await getProducts()

  return (
    <FilterShell>
      <ul>
        {products.map((p) => <ProductRow key={p.id} product={p} />)}
      </ul>
    </FilterShell>
  )
}
```

`ProductRow` is a Server Component. It is rendered on the server and passed into `FilterShell` as `children`, so it is never imported into the client graph and never bundled. The provider wraps server-rendered output — legal, and the reason `children` exists as an escape valve.

**Be honest about the trade this makes.** The rows no longer re-filter on the client, because the client no longer has the data. If the filter must be instantaneous and local, Stage 2 is the correct answer and the prop cost is the price. If the filter should live in the URL and re-query the server, this is the right shape and the next step is a `searchParams`-driven query. Naming which one you need is the actual design decision; the composition pattern is just the mechanism.

### Stage 4 — streaming a promise across the boundary

There is a third position between the two, useful when the client genuinely needs the data but shouldn't block on it: pass the **unresolved promise** as a prop and unwrap it with `use()`.

```tsx
// app/catalog/page.tsx
import { Suspense } from 'react'
import { getProducts } from '@/lib/catalog'
import { FilterableList } from './filterable-list'

export default function CatalogPage() {
  const productsPromise = getProducts()   // not awaited

  return (
    <Suspense fallback={<ListSkeleton />}>
      <FilterableList products={productsPromise} />
    </Suspense>
  )
}
```

```tsx
'use client'
import { use, useState } from 'react'

export function FilterableList({ products }: { products: Promise<Product[]> }) {
  const list = use(products)
  const [filter, setFilter] = useState('')
  // ...
}
```

The page component doesn't `await`, so it doesn't block; the boundary streams. Promises are serializable across the boundary precisely so this shape is available.

### Verify the loop

```bash
pnpm build
```

Stages 1–3 live under `app/catalog/_stages/` — a private folder — so they are **not routes** and will never appear in the build table. That is intentional (article 23's convention in place). Stage 4 is the live `app/catalog/page.tsx`. To compare stages, temporarily point that page at each stage export and rebuild; do not look for missing `/catalog` rows.

There is no First Load JS column in the 16.3 Turbopack build table, and `app-build-manifest.json` is not emitted. Measure route JS from the client-reference manifest instead:

```bash
# After a build that mounts the stage under /catalog:
# sum byte sizes of entryJSFiles for
# .next/server/app/catalog/page_client-reference-manifest.js
```

Measured on `next@16.3.0` (route `entryJSFiles` only; shared framework chunk `12_ov47oe8zv7.js` is 14 634 B in each run):

| Stage mounted as `/catalog` | Route-owned chunk | `entryJSFiles` total |
| --- | ---: | ---: |
| 1 (`_stages/stage1-page`) | 551 B | 15 185 B |
| 2 (`_stages/stage2-list`) | 452 B | 15 086 B |
| 3 (`filter-shell`) | 445 B | 15 079 B |

The deltas are noise at this catalog's size — stage 1 is not a meaningful KB outlier here. The costs that *do* change across stages are graph membership (whole page vs leaf), the data waterfall / API route, shell HTML (inspect `.next/server/app/catalog.html`), and prop/payload size — none of which the First Load column would have shown either. Use `@next/bundle-analyzer` when you need *which module*, not a toy KB table.

Then:

1. Open `.next/server/app/catalog.html` for stage 4 (or a temporarily mounted stage 1 / 3). Stage 1's list is absent from the prerender; stage 3's rows are present.
2. In Stage 2, inflate the product count to a few thousand and watch the RSC payload size in the network panel — the number no bundle report shows you.
3. In Stage 3, try to `import { ProductRow }` inside `filter-shell.tsx` and render it directly. Watch it break. That failure is the module-graph rule enforcing itself.

Step 3 is the one that makes `import`-versus-`children` stop being something you memorize.

---

## Then vs now

The Server/Client split itself is **stable since Next 13** — the module-graph rule, the serialization constraint, and the `children` escape hatch have not changed mechanism. What changed in 16 is the boundary's relationship to *rendering*, and that is real.

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 8, 14, 19.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Whether a Client Component prerenders | Determined by the **route's** classification: if anything de-opted the route, nothing on it was static | Determined per boundary: a Client Component is in the shell iff **its props** are computable at prerender time | Static/dynamic moved from a route-level flag consulted by the build planner to a per-subtree property decided by whether the prerender pass aborts while computing that subtree's inputs. |
| Route-reading client hooks | Read whatever the route rendering mode allowed; no boundary requirement | `usePathname` / `useParams` / `useSelectedLayoutSegment(s)` suspend under unknown dynamic params; `useSearchParams` always suspends | These hooks stopped being ordinary reads of ambient router state and became **suspendable reads of request-time data**. The prerender pass has no request, so the read has nothing to return and must suspend rather than lie. |
| Calling server code from a Client Component | Only via a Server Action (`'use server'`) or an API route | Also via importing the exports of a file-level `'use cache'` module and calling them directly | A file-level cache directive now generates the same kind of addressable server reference that `'use server'` does, so a second category of callable acquired a wire representation. |
| Navigating away from a Client Component | The tree unmounted; `useState`, inputs, and scroll were discarded | React `<Activity>` keeps the tree in `hidden` mode; effects clean up and re-run, state survives | The router stopped destroying the previous tree on navigation. Unmount was previously doing reset work by accident; that work is now explicit. |
| Client Component optimization | React Compiler via Babel, opt-in | React Compiler via Babel, plus an experimental Rust implementation inside Turbopack (16.3) | Compilation moved from a separate Babel pass that generates and reparses code into the bundler's own pipeline. Behavior is unchanged; build time is the point. |
| `runtime = 'edge'` for client-heavy routes | Supported | Deprecated; Cache Components requires the Node.js runtime | Runtime selection narrowed. Edge-shaped work moved to `proxy.ts`, which sits *outside* the rendering model entirely. |

---

## Real-world patterns

**Push the boundary to the leaf, and write down why it's there.** A `'use client'` with no comment is a boundary nobody will dare move in six months. `// client: needs useState for the open/closed toggle` costs one line and makes the boundary reviewable.

**Third-party components are boundaries too.** A library component that uses hooks internally but ships without `'use client'` forces you to wrap it in your own client file. That wrapper is a real part of your client graph — audit it like your own code.

**Providers wrap `children`, always.** Theme, query client, session: these go in a client file that takes `children`, and get mounted in a Server Component layout. Done that way, the provider costs you the provider — not the subtree.

**Prefer server composition to client context for server data.** If the reason you reached for context is "I don't want to prop-drill this down six levels," and the value comes from the server, the answer is usually server composition, or — for values above the root layout like `[lang]` — `next/root-params`, which reads them from any Server Component without prop-drilling at all.

**Watch prop size, not just bundle size.** Bundle size is measured for you and reported on every build. Payload size is not, and it is per-navigation. When a page feels heavy and the bundle report looks fine, measure the payload.

**Keep the boundary out of shared layouts.** The same lesson as runtime data reads: one client hook in a header multiplies across every route beneath it.

---

## API and type reference

| Surface | Where it goes | What it does |
| --- | --- | --- |
| `'use client'` | Top of a file, before imports | Declares an entry point into the client module graph. Its exports may be rendered directly by Server Components. |
| `'use server'` | Top of a file, or top of a function | Marks exported async functions as remotely callable Server Functions. **Not** the opposite of `'use client'`. |
| `'use cache'` (file level) | Top of a file | Exports become cached server functions; may also be imported and called from Client Components. |
| `children` / element props | Server Component → Client Component | Passes already-rendered server output through a client boundary without bundling it. |
| `Promise<T>` as a prop | Server Component → Client Component | Streams; unwrap on the client with `use()`. |
| `use(promise)` | `react` | Unwraps a promise inside a Client Component; suspends until it resolves. |
| `useSearchParams` | Client Component | Always suspends during prerendering. Requires a `<Suspense>` boundary. |
| `next/root-params` | Server Components | Reads params defined above the root layout without prop-drilling. |

---

## Common mistakes

**1. Reading `'use client'` as "client-only."** It still server-renders. Code that touches `window` at module scope or during the first render will still break, and the error will be a hydration error rather than the "undefined is not an object" you expected.

**2. Putting the directive on `page.tsx`.** The most expensive single line in a Next.js codebase. It pulls the whole route into the client graph and pushes data fetching to after hydration.

**3. Passing a function as a prop.**

```tsx
// ❌ Functions cannot be passed to Client Components
<ProductCard onSave={() => save(product.id)} />
```
Either the handler belongs inside the client component, or it is a Server Function marked `'use server'`.

**4. Importing a Server Component into a Client Component** and expecting it to stay on the server. The import is the thing that moves it. Pass it as `children` or an element prop instead.

**5. Passing a component function where an element is expected.** `<Modal content={CartContents} />` sends a function; `<Modal content={<CartContents />} />` sends output. The error message points at serialization and the cause is composition.

**6. Passing a class instance across the boundary.** An ORM model, a `Decimal`, a custom `Money` class — the fields may arrive and the methods will not. Map to a plain object at the boundary, deliberately.

**7. Shipping the dataset to render it.** If a Client Component receives an array only to `map` over it into non-interactive markup, the rows belong on the server behind a `children` slot.

**8. `useSearchParams` without a boundary** — and especially in a shared header, where the cost is every route below it.

**9. Assuming state resets on navigation.** With `<Activity>`, an open dropdown stays open and a submitted form keeps its `useActionState` result when the user comes back. Reset explicitly, or derive the state from the URL.

**10. Believing `'use server'` marks a Server Component.** It does not, and nothing does — Server Components are the default and have no directive. `'use server'` marks callable endpoints, which is a different axis entirely.

---

## Exercises

**1. Trace a graph.** Pick a route in an existing app and list every module that ends up in the client bundle. Start at each `'use client'` file and follow imports transitively. Compare your list against the build's chunk output.

*Hint: the surprises are almost always utility modules imported for one function, and icon libraries imported without tree-shaking.*

**2. Convert a boundary.** Find a Client Component that receives an array of data purely to render it. Restructure it into a `children` slot so the rows stay on the server. Compare `.next/server/app/<route>.html` and the RSC payload size before and after — not a First Load JS column.

*Hint: if the component also filters or sorts that array on the client, you have found a real trade-off rather than a mistake — write down which side you chose and why.*

**3. Break it deliberately.** In the walkthrough's Stage 3, import `ProductRow` directly inside `filter-shell.tsx`. Read the error. Then explain, in one sentence, why the `children` version works when the import version doesn't.

*Hint: the answer is about when the component was rendered, not about where it was declared.*

---

## Summary

- `'use client'` marks a **module-graph entry point**, not a runtime. The client graph is that file plus everything it imports.
- Client Components **still render on the server** and then hydrate. The directive controls bundling, not execution.
- The directive spreads through `import` and **not** through `children` — which is exactly why a Server Component can render inside a Client Component but cannot be imported by one.
- The RSC payload represents Client Components as module references plus serialized props. Serializability, and prop cost, both follow from that format.
- Server Functions cross the boundary because a reference to an endpoint has a wire representation. Closures do not.
- Under Cache Components, a Client Component is in the static shell iff its props are computable at prerender time — and route-reading client hooks suspend when they aren't.

---

## See also

- [`foundations/thinking-in-the-app-router`](./thinking-in-the-app-router.md) — the shell/hole model this boundary sits inside
- [`foundations/rules-of-the-server-boundary`](./rules-of-the-server-boundary.md) — the full contract for each scope
- [`performance/the-client-bundle`](../performance/the-client-bundle.md) — measuring the graph you just traced
- [`mutations/server-functions`](../mutations/server-functions.md) — the other side of the boundary
- [`routing/navigation-and-ui-state`](../routing/navigation-and-ui-state.md) — `<Activity>` and the state that no longer resets
- [`reactjs-concepts` → `state/context`](../../../../reactjs-concepts/docs/concepts/state/context.md) — what context is and isn't for, before you reach for a provider

---

## References

- Next.js — Getting Started: Server and Client Components
- Next.js — Directives: `use client`, `use server`, `use cache`
- Next.js — Guides: Interleaving Server and Client Components
- Next.js — Functions: `next/root-params`, `useSearchParams`
- Next.js — Messages: URL data in a Client Component outside of Suspense
- Next.js blog — Next.js 16.3 (2026-08-03)
- React — `use`, `<Activity>`, Server Components, `'use client'`

---

## Demo source

`demos/next-lab/app/catalog/` — stages 1–3 as `app/catalog/_stages/stage{1,2,3}-*.tsx`; stage 4 is `app/catalog/page.tsx`. Re-measure with `demos/next-lab/scripts/measure-catalog-stages.mjs`.

> **Verification status.** Version facts verified 2026-08-09 against the npm registry (`next@16.3.0`, `react@19.2.8`); demo measurements 2026-08-10. **Measured:** no First Load JS column / no `app-build-manifest.json` under Turbopack; route JS via `entryJSFiles` in `page_client-reference-manifest.js` (stage deltas above). Pending: the exact error text for importing a Server Component into a Client Component under Turbopack, and whether the RSC payload node shape in "How it works" should be a real captured payload fragment. Code blocks are **authored, not yet extracted** — replace via `scripts/build-article.py` before promoting out of `draft`.
