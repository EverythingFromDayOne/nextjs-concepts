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
verified_on: 2026-08-14
status: draft
---

# Server and Client Components

> **Lead with this.** `'use client'` does not mean "runs on the client." It means **"this module is an entry point into the client module graph."** The directive spreads through `import` and never through JSX children — which is why a Server Component can render *inside* a Client Component but cannot be imported by one.
>
> And the failure you are most likely to hit is the one that doesn't fail. Import a Server Component that happens to touch nothing server-only, and it silently becomes a Client Component: bundled, shipped, hydrated, and working. Nothing tells you.

This is the article [`reactjs-concepts`](../../../../reactjs-concepts/docs/roadmap.md) deferred when it fenced RSC as "coverage happens via Next.js App Router, since that's where RSC is actually usable in production."

---

## What it is

Your app has **one source tree and two module graphs**.

The **server graph** is everything reachable from the route tree without crossing a `'use client'` file. It runs on the server only. It never ships. It can touch the database, read secrets, and `await` freely.

The **client graph** starts at every file carrying `'use client'` and extends through everything those files import. It is bundled, shipped, parsed, and executed in the browser — and, first, executed on the server to produce initial HTML.

The directive is the seam. It goes on a *file*, before any imports, and that file's exports become entry points.

{EXTRACT:demos/next-lab/app/products/[slug]/add-to-cart.tsx}

You do **not** repeat it in every file underneath. A file imported by a Client Component is already in the client graph. You add the directive only where a Server Component renders directly into client-land.

### The two things everyone gets wrong

**1. `'use client'` is not "client-only."** Client Components are server-rendered to HTML on the first request, exactly like every SSR framework since 2016, and *then* hydrated. The directive controls **where the module lives**, not **where it executes**. Truly client-only behavior — reading `window`, measuring the DOM — still needs an effect or a client-only dynamic import.

**2. The directive spreads through `import`, not through JSX.**

- A component you **import** into a Client Component joins the client graph. It gets bundled.
- A component you receive as **`children`** does *not*. It was rendered on the server and arrives as output — the Client Component only decides *where to put it*, never *how to produce it*.

---

## How it works under the hood

### The RSC payload is not HTML

When the server renders a route it produces two things: streamed HTML for first paint, and an **RSC payload** — a serialized description of the rendered tree.

In that payload, Server Components have already collapsed into their output: elements, text, attributes. Nothing left to run. Client Components are different. They appear as a **client reference**: a module id, an export name, and the props they were given.

```
["$", "@42#QuantityPicker", null, { "max": 10 }]
      └─ module id + export        └─ serialized props
```

The browser resolves module 42 from the client bundle and mounts the component with those props.

Two consequences follow directly from that format, and one of them is measured below.

**Serializability is not a style rule.** A prop must have a representation in the payload. Primitives, plain objects and arrays, `Date`, `Map`, `Set`, typed arrays, `FormData`, JSX elements, and Promises all do. A closure does not — there is no way to send a function body. A class instance does not either, and the framework rejects it rather than degrading:

{EXTRACT:demos/next-lab/antipatterns/class-instance-prop.tsx}

Note the enforcement phase on that file. It is caught when the offending code is *rendered*, which means a prerendered route catches it at build and a postponed subtree does not catch it until a request arrives. See [`rules-of-the-server-boundary`](./rules-of-the-server-boundary.md) for the full matrix — the phase is a property of the route's shape, not of the violation.

**Server Functions are the single exception, for a principled reason.** A `'use server'` function *does* have a wire representation: a reference to an addressable endpoint, exactly as a client reference is a reference to an addressable module. The one kind of function that may cross is the one that is really an id in disguise.

### Props are re-serialized on every render

This is the cost that no bundle report shows, and it is why the boundary's *position* is a performance decision rather than an organisational one.

Props are not a one-time hydration cost. Every render that crosses the boundary re-serializes them into the payload. Passing a dataset to a Client Component to render a list means shipping that dataset on every navigation that re-renders the boundary.

Two shapes, identical visible output, measured — a `Stage2List` receiving the array as a prop (`payload-a-*`) against a `FilterShell`/`ProductRow` pair receiving it as already-rendered `children` (`payload-b-*`), at 40 and 4,000 products:

| Shape | Products | Bundle (`entryJSFiles`) | RSC payload only | Total HTML |
| --- | ---: | ---: | ---: | ---: |
| a — prop into `Stage2List` | 40 | 15,100 B | 10,046 B | 14,052 B |
| a — prop into `Stage2List` | 4,000 | 15,100 B | 553,470 B | 710,896 B |
| b — `children` through `FilterShell` | 40 | 15,093 B | 7,316 B | 12,269 B |
| b — `children` through `FilterShell` | 4,000 | 15,093 B | 317,673 B | 581,930 B |

{EXTRACT:demos/next-lab/observations/payload-boundary.txt}

The bundle rows are the control. They barely move — 15,100 B vs 15,093 B, a 7-byte rounding difference regardless of whether the route renders 40 products or 4,000 — because the *code* is nearly the same in both shapes. The RSC-payload column is where the boundary's position shows up: at 40 products the gap is 2,730 B (a is 1.37× b); at 4,000 it's 235,797 B (1.74×). **Report the size honestly: this confirms the direction of the claim, not the dramatic version of it.** Both payloads grow with the product count, because both shapes render the same list — what differs is the per-item overhead. `Stage2List` receives entire product records (`id`, `slug`, `description`, `priceCents`) as props whether or not it reads them; `ProductRow`'s output carries only what it actually rendered, a name and a formatted price. At 40 products that overhead is a few kilobytes, easy to miss next to everything else on the page. At 4,000 it is 236 KB that no bundle report will ever show you, paid again on every re-render that crosses the boundary — not once at load.

### Server Components have no client lifecycle

A Server Component produces payload and is gone. No state, no effects, no event handlers, no browser presence. Asking why `useEffect` doesn't run in one is asking why a function that finished on another machine has a lifecycle.

The corollary matters more than the rule: **re-rendering a Server Component is a network round trip.** In client React a re-render is a function call you can be casual about. Here it is a request returning a fresh payload that React reconciles into the existing tree.

### The silent conversion — the failure most people hit first

Importing a Server Component into a Client Component does not reliably break. What it does is **convert** it.

If the component uses `next/headers`, does unsuspended data access, or otherwise depends on the server, the build fails. If it does none of those — and most presentational components do none of those — it becomes a Client Component and everything keeps working. It is bundled, shipped, hydrated. Nothing in the build output announces that a component you designed to stay on the server is now in the browser, along with everything it imports.

{EXTRACT:demos/next-lab/antipatterns/imported-server-component.tsx}

That file's `next/headers` import gives it a loud failure. Most components don't have one. Measured against a pair with no server-only content at all — `convert-a` composes `ProductRow` as `children` through `FilterShell` (correct); `convert-b` imports `ProductRow` directly into a client file and renders it there:

{EXTRACT:demos/next-lab/observations/silent-conversion.txt}

Both routes build. Neither logs a warning. `convert-b`'s bundle grows by exactly `ProductRow`'s code — 274 B in this demo, inlined into the file that imported it rather than appearing as its own manifest entry — and that bundle diff is the *only* place the conversion shows up, and only if you go looking for it. Adding `import 'server-only'` to `product-row.tsx` turns the identical import into a **named build failure**: `You're importing a module that depends on "server-only" into a React Client Component module`, pointing at the exact line. And because this is a bundler-time import-graph check rather than a React render-time check, the guard is unconditional — unlike the class-instance check above, which only fires when the offending code actually renders and can be deferred to runtime by an unrelated dynamic API upstream, a `server-only` violation fails the build every time, regardless of what else the route does.

That is the failure mode to internalise, because it is the one that does not announce itself — and `server-only` is the one-line fix that makes it announce itself.

### Where the boundary sits relative to the shell

A Client Component lands **in the static shell** if its props are computable during the prerender. `<QuantityPicker max={10} />` prerenders fine. `<QuantityPicker max={await getStock(slug)} />` does not — the abort happens while computing the prop, above the client boundary.

The same logic explains a rule that otherwise looks like a quirk: client hooks that read the route **suspend during prerendering**. `usePathname`, `useParams`, and `useSelectedLayoutSegment(s)` suspend under dynamic params; `useSearchParams` always does, because search params are only known at request time.

They suspend *wherever they sit* — including in a nav or breadcrumb in a shared layout, which is how one `useSearchParams` in a header costs the shell for every route beneath it.

### Calling cached server functions from the client

One boundary is deliberately porous. With a cache directive at the **top of a file**, that file's exports can be imported into a Client Component and called directly. They execute on the server and return their result.

Useful, and worth being deliberate about: the documented preference is still to call cached functions on the server and pass results down. Reach for the direct call when the *trigger* is genuinely a client interaction, not to avoid thinking about composition.

---

## Basic usage

The default is Server. You opt into Client, at a leaf, for a stated reason.

{EXTRACT:demos/next-lab/app/catalog/product-row.tsx}

{EXTRACT:demos/next-lab/app/catalog/filter-shell.tsx}

The rows stay on the server. Only the input ships.

---

## Walkthrough — moving a boundary down, in four stages

The feature: a product list with a client-side text filter.

### Stage 1 — the version that looks reasonable

{EXTRACT:demos/next-lab/app/catalog/_stages/stage1-page.tsx}

Four costs, none obvious from reading it: the whole subtree joins the client graph; data loads *after* hydration; you needed an API route that exists only for your own page; and the shell contains an empty list.

### Stage 2 — server data, client filter

{EXTRACT:demos/next-lab/app/catalog/_stages/stage2-page.tsx}

{EXTRACT:demos/next-lab/app/catalog/_stages/stage2-list.tsx}

The waterfall and the API route are gone. But every product now crosses the boundary as a serialized prop — the cost measured in the payload table above.

### Stage 3 — the slot

The rows are not interactive. Only the input is. So let the client component own the state and the layout, and receive the rows as already-rendered output.

{EXTRACT:demos/next-lab/app/catalog/_stages/stage3-page.tsx}

`ProductRow` is a Server Component, rendered on the server and passed in as `children`, so it never enters the client graph.

**Be honest about the trade.** The rows no longer re-filter on the client, because the client no longer has the data. If the filter must be instantaneous and local, **stage 2 is correct, and the measured payload gap — 1.37×–1.74× larger than stage 3's shape, not an order of magnitude — is the price.** If the filter belongs in the URL and should re-query the server, this is the right shape. Naming which one you need is the design decision; the composition pattern is just the mechanism.

### Stage 4 — streaming a promise across the boundary

Between the two: pass the **unresolved promise** and unwrap it with `use()`.

{EXTRACT:demos/next-lab/app/catalog/page.tsx}

{EXTRACT:demos/next-lab/app/catalog/filterable-list.tsx}

The page never awaits, so it never blocks; the boundary streams.

### Verify the loop

```bash
pnpm build
pnpm start
```

1. Compare payload bytes across the four shapes, not bundle sizes. The bundle rows are nearly identical.
2. Read `.next/server/app/catalog.html` — not view-source, which shows a completed stream.
3. Import `ProductRow` directly inside `filter-shell.tsx` and rebuild. **It will not fail.** Check the bundle rows instead: that is the silent conversion, and the bundle is the only place it shows.

Step 3 is the one that makes `import`-versus-`children` stop being something you memorize.

---

## Then vs now

The Server/Client split is **stable since Next 13** — the module-graph rule, the serialization constraint, and the `children` escape hatch have not changed mechanism. What changed in 16 is the boundary's relationship to *rendering*.

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 8, 14, 19.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Whether a Client Component prerenders | Determined by the **route's** classification | Determined per boundary: in the shell iff **its props** are computable at prerender time | Static/dynamic moved from a route-level flag the build planner consulted to a per-subtree property decided by whether the prerender aborts while computing that subtree's inputs. |
| Route-reading client hooks | Ordinary reads of ambient router state | `usePathname` / `useParams` / `useSelectedLayoutSegment(s)` suspend under dynamic params; `useSearchParams` always | These became **suspendable reads of request-time data**. The prerender has no request, so the read has nothing to return and must suspend rather than lie. |
| When a boundary violation is caught | At build, if at all | At build *only if the containing subtree is prerendered* | Violations that need React to render the offending code are deferred along with the subtree. An outer dynamic API silences build-time enforcement for everything below it. |
| Calling server code from a Client Component | Only via `'use server'` or an API route | Also by importing file-level `'use cache'` exports and calling them | A second category of callable acquired a wire representation. |
| Navigating away | The tree unmounted; state discarded | `<Activity>` keeps it in `hidden` mode; effects clean up and re-run, state survives | The router stopped destroying the previous tree. Unmount was doing reset work by accident; that work is now explicit. |
| `runtime = 'edge'` | Supported | Deprecated; Cache Components requires Node.js | Runtime selection narrowed. Edge-shaped work moved to `proxy.ts`, outside the rendering model. |

---

## Real-world patterns

**Push the boundary to the leaf, and write down why.** A `'use client'` with no comment is a boundary nobody will dare move in six months.

**Guard genuinely server-only modules with `server-only`.** It is the one-line defence against the silent conversion — see the conversion result above for what it changes and when it fires.

**Watch payload size, not just bundle size.** Bundle size is measured for you on every build — and it barely moved between the two shapes measured above. Payload size is not measured for you, it is per-navigation, and it is where the two shapes actually diverged: modestly at dozens of rows, by hundreds of kilobytes at thousands. When a page feels heavy and the bundle report looks fine, measure the payload instead of guessing at its size.

**Map at the boundary.** ORM models, `Decimal`, custom value types: convert to plain objects deliberately, in one place per entity.

**Providers wrap `children`, always.** Done that way, the provider costs you the provider — not the subtree.

**Third-party components are boundaries too.** A library component using hooks without shipping `'use client'` forces you to wrap it. That wrapper is part of your client graph; audit it like your own code.

**Keep the boundary out of shared layouts.** One client hook in a header multiplies across every route beneath it.

---

## API and type reference

| Surface | Where it goes | What it does |
| --- | --- | --- |
| `'use client'` | Top of a file, before imports | Declares an entry point into the client module graph. |
| `'use server'` | Top of a file or function | Marks exported async functions as remotely callable. **Not** the opposite of `'use client'`. |
| `'use cache'` (file level) | Top of a file | Exports become cached server functions, importable and callable from Client Components. |
| `server-only` | `import 'server-only'` | Turns a silent conversion into an error. |
| `children` / element props | Server → Client | Passes rendered server output through a client boundary without bundling it. |
| `Promise<T>` as a prop | Server → Client | Streams; unwrap with `use()`. |
| `useSearchParams` | Client Component | Always suspends during prerendering. |
| `next/root-params` | Server Components | Reads params above the root layout without prop-drilling. |

---

## Common mistakes

**1. Reading `'use client'` as "client-only."** It still server-renders. Module-scope `window` access breaks with a hydration error, not the reference error you expected.

**2. Putting the directive on `page.tsx`.** The most expensive single line in a Next.js codebase.

**3. Importing a Server Component into a Client Component.** The dangerous case is the one that **works** — no server-only content, so it silently becomes a Client Component and ships. Pass it as `children`, and use `server-only` where the module must never cross.

**4. Passing a function as a prop.** No wire representation. Either the handler belongs inside the client component, or it is a Server Function.

**5. Passing a class instance.** Rejected — and *when* you find out depends on whether the subtree was prerendered. Map to a plain object at the boundary.

**6. Shipping the dataset to render it.** If a Client Component receives an array only to map it into non-interactive markup, the rows belong on the server behind a `children` slot. The cost shows up in the payload table, not the bundle report — measured at 1.37×–1.74× here, growing with row count, not a dramatic one-time hit.

**7. `useSearchParams` without a boundary** — especially in a shared header.

**8. Assuming state resets on navigation.** With `<Activity>`, an open dropdown stays open and a submitted form keeps its `useActionState` result.

**9. Believing `'use server'` marks a Server Component.** It marks callable endpoints. Server Components are the default and have no directive.

---

## Exercises

**1. Trace a graph.** Pick a route and list every module that ends up in the client bundle, starting from each `'use client'` file and following imports transitively. Compare against the build's chunk output.

*Hint: the surprises are utility modules imported for one function, and components someone imported instead of slotting.*

**2. Find a silent conversion.** Search your app for Server Components imported into `'use client'` files. Any that don't error are shipping to the browser. Add `server-only` to one that shouldn't be and see what happens.

**3. Measure a boundary.** Take a Client Component receiving an array purely to render it. Record response bytes, restructure it into a `children` slot, record again.

*Hint: if it also filters that array on the client, you have found a real trade-off rather than a mistake. Write down which side you chose and why.*

---

## Summary

- `'use client'` marks a **module-graph entry point**, not a runtime. Client Components still render on the server first.
- The directive spreads through `import` and **not** through `children` — which is why a Server Component can render inside a Client Component but cannot be imported by one.
- The RSC payload represents Client Components as module references plus serialized props. Serializability and per-render payload cost both follow from that format.
- **Props are re-serialized on every render.** Boundary position is a bandwidth decision the bundle report cannot see — measured at a modest but real 1.37×–1.74× here, confirming the direction, not a dramatic multiple.
- Importing a Server Component **converts** it. When it has no server-only content the conversion is silent — the most common and least visible mistake in the model.
- A class instance is rejected, but *when* depends on whether the containing subtree was prerendered.
- Server Functions cross because a reference to an endpoint has a wire representation. Closures do not.

---

## See also

- [`foundations/thinking-in-the-app-router`](./thinking-in-the-app-router.md) — the shell/hole model this boundary sits inside
- [`foundations/rules-of-the-server-boundary`](./rules-of-the-server-boundary.md) — the full enforcement matrix, including the phase-dependence
- [`rendering/static-shell-and-streaming`](../rendering/static-shell-and-streaming.md) — why prerendering decides when violations surface
- [`performance/the-client-bundle`](../performance/the-client-bundle.md) — measuring the graph you traced
- [`mutations/server-functions`](../mutations/server-functions.md) — the other side of the boundary
- [`routing/navigation-and-ui-state`](../routing/navigation-and-ui-state.md) — `<Activity>` and the state that no longer resets

---

## References

- Next.js — Getting Started: Server and Client Components
- Next.js — Directives: `use client`, `use server`, `use cache`
- Next.js — Guides: Interleaving Server and Client Components
- Next.js — Functions: `next/root-params`, `useSearchParams`
- React — `use`, `<Activity>`, Server Components, `'use client'`

---

## Demo source

`demos/next-lab/app/catalog/` including `_stages/`, `demos/next-lab/app/products/[slug]/add-to-cart.tsx`, the two named files in `demos/next-lab/antipatterns/`, `lib/db.ts`'s `makeProducts` generator, and `observations/payload-boundary.txt` and `observations/silent-conversion.txt`. Re-measure with `demos/next-lab/scripts/session8-observe.mjs` (`payload` and `convert` modes) — both scratch route pairs it builds are deleted after each run.

> **Verification status.** Verified against `next@16.3.0`. This article **supersedes** the session-2 draft, which contained three claims session 7 measured as wrong: that a class instance degrades silently (it is rejected, with phase depending on prerendering); that importing a Server Component reliably fails (it silently converts when the component has no server-only content); and it did not discuss enforcement phase at all. The payload cost was the article's central claim from the beginning and was **unmeasured until this session** — real, and it holds the direction the article always claimed, but the measured size is moderate (1.37×–1.74×, driven by unused fields riding along in the props, not by data volume in general) rather than the dramatic gap the earlier draft implied without a number attached; the rewrite reports that plainly instead of rounding up. Every code block is extracted.
