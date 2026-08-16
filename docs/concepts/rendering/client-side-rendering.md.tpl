---
article_id: client-side-rendering
description: Client-side rendering is a legitimate fourth answer, and the mistake is choosing it for a page rather than for a boundary
concept_folder: rendering
wave: 1
related:
  - foundations/thinking-in-the-app-router
  - foundations/server-and-client-components
  - caching/cache-components-model
  - performance/the-client-bundle
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-14
status: draft
---

# Client-side rendering

> **Lead with this.** This is the fourth answer — the one that says *don't compute this on the server at all.* It is a legitimate choice, not a failure to adopt Server Components, and there are values for which it is the only correct one.
>
> The mistake is not choosing it. The mistake is choosing it **for a page** rather than **for a boundary**, which is what the old CSR-versus-SSR framing trained everyone to do.

---

## What it is

Every piece of data in a route gets one of four answers. Three of them happen on the server:

| Answer | Mechanism | Runs |
| --- | --- | --- |
| Cache it | `'use cache'` | Ahead of the request |
| Stream it | `<Suspense>` | Per request |
| Block on it | `instant = false` | Per request, before the response |
| **Push it to the client** | `'use client'` + effects, or `ssr: false` | In the browser, after hydration |

The fourth is correct when the value **does not exist on the server**. Not "is inconvenient to get" — does not exist:

- **Device facts.** Viewport, `devicePixelRatio`, pointer type, colour scheme, `prefers-reduced-motion`, timezone, locale as the browser reports it.
- **High-frequency interaction.** Drag, draw, scroll-linked animation, anything at pointer or frame rate. A round trip per event is not a latency problem, it's a category error.
- **Mutable browser objects.** Canvas contexts, `IntersectionObserver`, media elements, WebGL, the DOM itself.
- **Live connections.** WebSockets, `EventSource`. The connection belongs to the tab.
- **Data whose freshness the user controls.** Polling a dashboard the user is watching, where "current" means since they last looked.

If your value isn't in that list, the fourth answer is probably the wrong one — and worth defending explicitly if you pick it anyway.

---

## How it works under the hood

### Client-side rendering is not one thing

Two mechanisms get called CSR and they behave differently.

**Hydration-deferred.** A Client Component renders on the server, ships as HTML, hydrates, and *then* an effect fills in the browser-only part. The content exists in the prerendered HTML — in its empty state.

**Never-server-rendered.** `next/dynamic` with `ssr: false` skips server rendering entirely. The `loading` fallback goes in the HTML; the real component does not exist until the bundle arrives and executes.

The second is heavier and is the right tool only when the component genuinely *cannot* run on a server — reads `window` during render, or pulls in a library that touches the DOM at module scope.

{EXTRACT:demos/next-lab/app/client-only/heavy-widget.tsx}

{EXTRACT:demos/next-lab/app/client-only/loader.tsx}

**Measured, not assumed.** Calling `dynamic(() => import(...), { ssr: false })` directly in a Server Component — no `'use client'` file in between — was tried as a scratch route and removed once the result was captured (`observations/ssr-false-in-server-component.txt`). It does not build:

```
Error: `ssr: false` is not allowed with `next/dynamic` in Server Components. Please move it into a Client Component.
```

That's a Turbopack compile error at `next build`, not a runtime throw, and it matches `node_modules/next/dist/docs/01-app/02-guides/lazy-loading.md` word for word. The §2 indirection is confirmed, not corrected: `loader.tsx` exists because there is nowhere else for `ssr: false` to legally go.

### The null first render is a contract, not a workaround

A Client Component's first render happens on the server, and the browser must produce the same output during hydration. So a browser-only value cannot appear in the first render — it has to start absent and arrive in an effect.

That is why the pattern looks the way it does, and why `typeof window === 'undefined'` guards multiply: each one is a place where the server and the client genuinely disagree, and the server's answer has to be rendered first.

### What actually lands in the HTML

The SEO argument around CSR is mostly folklore in both directions. What can be measured is what the server writes:

**Provenance and limit:** produced 2026-08-14 against `next@16.3.0` by running `pnpm build` and reading `.next/server/app/<route>.html` directly (`observations/client-only-shell.txt`) — never a response body, per this repo's measurement standard, since a streamed response contains both the fallback and the resolved content. **This measures what the build writes into the HTML file. It says nothing about what any crawler executes, renders, or indexes** — that is not observable from a build artifact, and nothing below claims it.

| Route | Build classification | What's inside `<main>`…`</main>` |
| --- | --- | --- |
| `/client-only` | `○ Static` | The heading and the static paragraph. In place of the widget: `<!--$!--><template data-dgst="BAILOUT_TO_CLIENT_SIDE_RENDERING"></template><p>Loading widget…</p>` — the `loading` fallback, wrapped in the literal bailout marker Next writes when `ssr: false` skips rendering. |
| `/sketchpad` | `○ Static` | The heading, the prose, **and the `<canvas>` element itself**: `<canvas style="width:100%;height:300px;border:1px solid #ccc"></canvas>`, with no `width`/`height` (set by a `useEffect`) and "0 strokes" (no pointer event has fired yet). The tag is there; the drawing isn't. |
| `/catalog` (contrast) | `○ Static` | No `<main>` at all — the page returns a bare `<Suspense>`, not a landmark, so there's nothing to trim to. What's there instead is fully resolved: `<input placeholder="Filter…" .../><ul><li>Aeron Chair — $1,495.00</li>…</ul>` — real product data, not a fallback, because this route's Server Component fetch had already resolved when the shell was written. |

What follows from the measurement alone is narrower and still useful: content that isn't in the HTML depends on a client executing your bundle successfully. That's a real dependency with real failure modes — bundle errors, slow devices, anything that reads HTML without running JavaScript — and it is a cost you should choose deliberately rather than inherit.

**Correction to the working assumption going in:** the asymmetry isn't prose-versus-canvas — the `<canvas>` tag is measurably present. It's hydration-deferred-versus-`ssr: false`. Sketchpad's tag renders empty because a plain `'use client'` component still server-renders; the client-only widget's output doesn't render *at all* because `ssr: false` skipped that step, and the fallback stands in instead. **The cost of `ssr: false` is that component's entire HTML. The cost of a hydration-deferred component is only its content — the element itself still ships.**

### Client fetching alongside Server Components

**Experiment C was skipped** (`observations/query-double-fetch.txt`). Measuring it properly means adding TanStack Query to `demos/next-lab` for one demo page — a dependency this repo's own roadmap already assigns elsewhere ("`reactjs-concepts` owns TanStack Query," `roadmap.md` §2), and flags as exactly the kind of invented, not-yet-approved addition its §7 list exists to catch before it lands silently.

The mechanism doesn't need the dependency to state correctly, because this repo already has the correct baseline to contrast against. `app/catalog/` passes a fetch `Promise` into a Client Component that unwraps it with `use()` — the data crosses the server/client boundary exactly once, serialized into the RSC payload that ships with the page. A Client Component that instead called `useQuery` (or any client fetch) against a route handler for data a Server Component already fetched would issue a second, independent `fetch()` after hydration, to a different endpoint, returning its own JSON body. The data crosses the wire twice — once inside the payload, once as a fresh request — regardless of which client library makes that second call. A DevTools network panel would show a request for data the page already had.

The design question underneath: a client fetching library and Server Components solve overlapping problems. Server Components answer "get this data before first paint." A query library answers "keep this data fresh while the user watches it, and let them refetch."

Where a query library earns its place: polling, optimistic mutation flows with rollback, infinite lists whose cursor lives in client state, and anything the user explicitly refreshes. Where it duplicates work you already have: initial page data that a Server Component could have fetched, cached, and streamed.

The failure to avoid is fetching the same data twice — once into the payload as a prop, once again from the client on mount. See [`reactjs-concepts` → `data-fetching`](../../../../reactjs-concepts/docs/concepts/data/data-fetching.md) for the library-side patterns; this repo covers only the boundary question.

---

## Basic usage

Client-side where the value is genuinely a browser fact, server-rendered everywhere else:

{EXTRACT:demos/next-lab/app/sketchpad/page.tsx}

{EXTRACT:demos/next-lab/app/sketchpad/sketchpad.tsx}

The page is a Server Component. The heading and prose prerender. Only the canvas is client-side, because pointer events at 60Hz and a mutable canvas context have no server representation.

---

## Walkthrough — three components, three different answers

A settings page with three pieces of state that look similar and are not.

### Step 1 — classify before writing

| Value | Exists on the server? | Answer |
| --- | --- | --- |
| The user's saved preferences | Yes, in the database | **Stream it** — read the session outside a cached scope, fetch, render server-side |
| System colour-scheme preference | No — a browser media query | **Push it to the client** |
| A live preview of the chosen theme | No — depends on the two above, interactively | **Push it to the client** |

Two of three are client-side, and the page is still mostly server-rendered. That is the normal outcome, and it is invisible if you decide per page.

### Step 2 — the server half stays server

The saved preferences come from the database, so they follow the same rule as everything else: read identity outside the cached scope, pass it in as an argument.

### Step 3 — the browser half starts null

The colour-scheme read has to render as absent on the server and arrive in an effect. Not a workaround — the server has no answer, so there is nothing else it could render.

### Step 4 — only reach for `ssr: false` when server rendering is impossible

A theme preview that reads `window.matchMedia` during render *cannot* server-render. That is the qualifying condition. A component that merely prefers client data does not qualify — it starts null and fills in.

### Step 5 — verify the loop

```bash
pnpm build && pnpm start
```

1. Read `.next/server/app/sketchpad.html`. Heading and prose present; the `<canvas>` tag is present too, empty — no drawn strokes, no `width`/`height`.
2. Read `.next/server/app/client-only.html`. The `loading` fallback is there; the widget's output is not there at all.
3. Compare both against `.next/server/app/catalog.html`.
4. Disable JavaScript and load all three. What remains is what a non-executing client gets — the same content the HTML files showed.

Step 4 is the honest version of the SEO question: it shows the floor, without claiming to know what any crawler does above it.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 8, 19, 20.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| CSR as a concept | One of four rendering strategies you chose **per page** — CSR, SSR, SSG, ISR | One of four answers you choose **per boundary** | Rendering mode stopped being a route-level classification the build planner consulted. A single route now spans all four answers, so the taxonomy has no unit to attach to. |
| Getting a client-only render | `dynamic(..., { ssr: false })`, or `useEffect` + state, or a page-level `'use client'` | Same primitives, but the page-level version is now a much larger cost | With prerendering as the default, a `'use client'` page root removes content from a shell that would otherwise exist — a cost that didn't exist when the route wasn't prerendering anyway. |
| Client state across navigation | Unmounted and discarded | `<Activity>` in `hidden` mode preserves `useState`, inputs, scroll | The router stopped destroying the previous tree, which makes client state cheaper to keep and resets an explicit act. |
| Client-fetched initial data | The default pattern in a Pages Router SPA | Usually redundant — a Server Component can fetch, cache, and stream it | The server gained the ability to fetch *per component* rather than per page, so the reason client fetching existed for initial load largely went away. |

---

## Real-world patterns

**Classify per value, never per page.** The question is "does this exist on the server," asked once per piece of state. Most pages come out mixed.

**Prefer hydration-deferred to `ssr: false`.** Starting null and filling in an effect keeps the surrounding HTML. Skipping server rendering entirely is for components that genuinely cannot run there.

**Name the qualifying condition in a comment.** `// client: devicePixelRatio has no server value` survives review. `'use client'` alone does not.

**Push the boundary to the leaf.** The sketchpad page is the shape to copy: a Server Component page with one client island, not a client page with server data threaded in.

**Don't fetch on the client what the server already sent.** The commonest waste in a hybrid app is a `useEffect` fetching data that arrived in the payload as a prop.

**Reach for a query library for freshness, not for first paint.** Polling, refetch-on-focus, optimistic rollback — those are its job. Initial data is the server's.

### When not to reach for Next.js at all

Worth saying plainly. If your product is a canvas, an editor, a game, or an internal tool behind a login where **every** meaningful surface is high-frequency interaction on browser-owned state, the four-answer model has one answer for you, and a framework built around prerendering is machinery you're paying for and not using. A Vite SPA is a reasonable choice there, and choosing it is not a failure.

The counter-case: most products that *feel* like this still have marketing pages, docs, settings, onboarding, and share links — surfaces where the other three answers are correct. The mixed shape is more common than either extreme.

---

## API and type reference

| Surface | Import | Role |
| --- | --- | --- |
| `'use client'` | directive | Entry point into the client module graph. Still server-renders. |
| `dynamic(fn, { ssr: false })` | `next/dynamic` | Skips server rendering entirely. Must live in a client module — see the measured result above. |
| `loading` option | `next/dynamic` | What lands in the HTML in place of the component. |
| `useEffect` | `react` | Where browser-only values arrive after hydration. |
| `useSyncExternalStore` | `react` | Subscribing to a browser store with a server snapshot, hydration-safe. |
| `<Activity>` | `react` | Why client state now survives navigation. |

---

## Common mistakes

**1. `'use client'` on the page for a mostly-static page.** It works, which is why it survives review. The prose leaves the prerendered HTML and the whole subtree joins the bundle.

{EXTRACT:demos/next-lab/antipatterns/client-page-for-static-content.tsx}

**2. `ssr: false` as a hydration-error fix.** It silences the error by not rendering on the server. If the component *could* server-render, you have removed content from the HTML to avoid fixing a mismatch.

**3. Fetching in `useEffect` data the server already had.** Costs a round trip after hydration and a loading state the user didn't need.

**4. Reading `window` during render.** Breaks hydration rather than throwing. Start null, fill in an effect.

**5. Treating "it's interactive" as the qualifying condition.** A form is interactive and server-renders fine. The condition is whether the *value* exists on the server.

**6. Assuming client state resets on navigation.** With `<Activity>`, it doesn't. Reset explicitly or derive from the URL.

**7. Using a query library for initial page data.** It'll work. It also duplicates a fetch the server could have cached and streamed.

**8. Deciding CSR-versus-SSR for the app.** The unit is a boundary. An app-wide answer is the old taxonomy speaking.

---

## Exercises

**1. Classify a settings page.** List every piece of state and mark each: exists on the server, or not. Count how many are genuinely client-only. Most people overestimate before counting.

**2. Measure what you removed.** Take a page with `'use client'` at the root, read its prerendered HTML, move the directive to the smallest leaf that needs it, read it again.

*Hint: read `.next/server/app/<route>.html`, not view-source — view-source shows a completed stream.*

**3. Find a redundant fetch.** Search for `useEffect` blocks that fetch data also available to a Server Component on the same route. Each one is a round trip after hydration.

---

## Summary

- Client-side rendering is the **fourth answer**, and it is correct when the value does not exist on the server.
- Two mechanisms: **hydration-deferred** keeps the surrounding HTML; **`ssr: false`** skips server rendering entirely and costs the component's HTML.
- The null first render is a hydration contract, not a workaround.
- What can be measured is **what is in the prerendered HTML**. Crawler behaviour cannot be measured from here and this article doesn't claim it.
- Pushing one component to the client costs that component's output, not the page's — and *how much* depends on the mechanism: hydration-deferred still ships the tag, empty; `ssr: false` ships none of it.
- Query libraries earn their place on **freshness**, not first paint.
- The unit of the decision is a **boundary**. An app-wide CSR-versus-SSR answer is the retired taxonomy talking.

---

## See also

- [`foundations/thinking-in-the-app-router`](../foundations/thinking-in-the-app-router.md) — the four answers, of which this is the fourth
- [`foundations/server-and-client-components`](../foundations/server-and-client-components.md) — the module graph and payload cost
- [`rendering/static-shell-and-streaming`](./static-shell-and-streaming.md) — what you keep by not going client-side
- [`performance/the-client-bundle`](../performance/the-client-bundle.md) — measuring what shipped
- [`routing/navigation-and-ui-state`](../routing/navigation-and-ui-state.md) — `<Activity>` and preserved client state

---

## References

- Next.js — Getting Started: Server and Client Components
- Next.js — Functions: `next/dynamic`
- Next.js — Guides: Lazy Loading
- React — `useEffect`, `useSyncExternalStore`, `<Activity>`, hydration

---

## Demo source

`demos/next-lab/app/sketchpad/`, `demos/next-lab/app/client-only/`, `demos/next-lab/antipatterns/client-page-for-static-content.tsx`, and the capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0`. **This article closes a gap in the repository's own model:** articles 1 and 6 assert four answers and only three had owning articles. All three measurements planned for this session are resolved: (1) what lands in the prerendered HTML for `/client-only`, `/sketchpad`, and (for contrast) `/catalog` — `observations/client-only-shell.txt`, and it corrected a working assumption in the process (the sketchpad row's `<canvas>` tag is measurably present, empty, not absent — the real asymmetry is hydration-deferred vs. `ssr: false`, not prose vs. canvas); (2) `ssr: false` directly in a Server Component does not build — a Turbopack compile error, confirming rather than correcting the §2 assumption — `observations/ssr-false-in-server-component.txt`; (3) Experiment C (client-fetch duplicating payload data) was deliberately skipped rather than run, because it requires adding TanStack Query — a dependency `roadmap.md` §2 already assigns to `reactjs-concepts` and §7 exists to flag before it lands unreviewed — `observations/query-double-fetch.txt` records the mechanism via the repo's existing `app/catalog/` baseline instead. The SEO discussion is **deliberately bounded to what the HTML contains**; crawler behaviour is not measurable here and is not asserted.
