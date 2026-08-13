---
article_id: rules-of-the-server-boundary
concept_folder: foundations
wave: 1
related:
  - foundations/server-and-client-components
  - foundations/build-time-request-time-and-the-client
  - caching/cache-components-model
  - mutations/server-functions
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-10
status: draft
---

# Rules of the server boundary

> **Lead with this.** There are four scopes — cached, Server Component, Client Component, Server Function — and each forbids things the others allow. The rules are not arbitrary; every one falls out of two facts. But they are **not equally enforced**, and that is the part worth knowing: some violations fail your build, some throw at request time, and at least one fails silently into a value that looks correct.
>
> Where the framework has your back, write freely. Where it doesn't, you need discipline — and the only way to know which is which is to have measured it.

---

## What it is

Two facts generate every rule in this article.

**Fact one: the prerender has no request.** Not an empty one. Absent. So anything that reads the request either suspends or fails, depending on whether it can wait.

**Fact two: the client boundary is a wire.** Values crossing it must have a serialized form. So anything without one — a closure, a prototype, a database handle — cannot cross.

Everything below is one of those two, applied to a scope.

---

## The four scopes

### Cached scope — `'use cache'`

The value is stored and replayed. So it may not depend on anything the key doesn't contain, and the key contains the arguments.

- Must be `async`.
- **No runtime APIs.** `cookies()`, `headers()`, `connection()` are all rejected — a cache entry that depends on the connection has no reuse.
- **Sync IO is permitted, and freezes.** `new Date()` inside a cached scope is legal and is captured at entry creation. This looks like an inconsistency with the rule above and isn't: see "One rule, two outcomes" below.
- Arguments and return value must be serializable — the arguments *are* the key.
- `cacheLife` cannot be called at module scope.
- `children` and slots pass **through** without being cached.
- With the directive at file level, exports may be imported into Client Components and called directly.

### Server Component — the default

Runs on the server, produces payload, and is gone. It has no browser existence, so it has no browser lifecycle.

- No `useState`, no `useEffect`, no event handlers. Not "discouraged" — there is no client instance to attach them to.
- May be `async` and may `await` freely.
- Runtime APIs are allowed but **abort the prerender** at the call site.
- May render Client Components; the props must serialize.
- **Importing one into a Client Component doesn't error — it reclassifies.** There is no compiler flag on a plain module that says "this is a Server Component"; a directive-less file reached through a `'use client'` import graph simply becomes part of the client bundle too, silently (probe 8 in the matrix below — measured, not assumed). The build only fails afterward, if that now-reclassified module then uses something the client bundle genuinely cannot run: a Node-only API like `next/headers` (a clear, specific error), or uncached data access outside `<Suspense>` (the same generic prerender error any route would get, unrelated to the boundary). Pass it as `children` or an element prop instead, and it stays a Server Component.

### Client Component — `'use client'`

An entry point into the client module graph. Not "client-only" — it renders on the server first, then hydrates.

- No server-only modules, no database handles, no secrets. Everything it imports ships.
- Route-reading hooks suspend during the prerender: `usePathname`, `useParams`, `useSelectedLayoutSegment(s)`, and `useSearchParams` always.
- May receive a `Promise` and unwrap it with `use()`.
- May import and call the exports of a file-level `'use cache'` module.

### Server Function — `'use server'`

A generated HTTP endpoint with a public id. Every rule follows from *public*.

- All exports must be `async`.
- **Authorize inside every one.** The UI that called it is not authorization, and hiding a button does not remove the endpoint.
- Arguments and return value must serialize; closure captures are serialized into the reference, so anything closed over travels with it.
- `updateTag` is available here and only here.

---

## One rule, two outcomes

The most confusing pair in the model: `cookies()` inside a cached scope is rejected, and `new Date()` inside the same scope is fine.

They are one rule.

> **A cached scope may hold a value whose staleness is bounded, and may not hold one whose staleness is unbounded.**

A timestamp inside a cached scope is part of an entry that expires — it is exactly as stale as the data beside it, and `cacheLife` says how stale that can get. A cookie is not bounded by anything; it changes per visitor, and no lifetime makes a stored copy correct for the next one.

*(This unification is an inference from two measured behaviors, not documented rationale. The measurements are in the matrix below; the reading is mine.)*

The trap that falls out is worth stating plainly, because nothing in the rendered output reveals it: **a cached timestamp describes when the entry was created, never when it was read.** The looser the lifetime, the worse it gets — `cacheLife('minutes')` yields a value minutes old that reads as *now*, and `cacheLife('max')` yields one that may be weeks old and reads identically.

---

## The enforcement matrix

Every row below was produced by writing the violation, building, and — where it built — requesting the route. Nothing here is inferred from documentation.

**The thesis: enforcement follows execution, and Suspense decides execution.** A violation is caught the instant something actually runs the code that breaks the rule — never earlier, no matter how serious the rule sounds. That instant falls into exactly two real categories, and every probe below belongs to one of them (probe 5 isn't a violation at all, and probe 8 spans both — see the notes after the table):

- **Caught before rendering — the module graph, or a synchronous throw at module-load time. Route-shape independent.** (probes 1, 2, 6, 11) These fail during `next build`'s compile step or its page-data-collection step, whether or not the route in question would ever prerender. No `Suspense` boundary anywhere changes this outcome, because the check runs against the code itself, before any component renders.
- **Caught during rendering — a build failure only if the containing subtree is actually prerendered.** (probes 3, 4, 7, 9, 10) These are evaluated when React tries to render the component that holds the violation. If nothing upstream of it is dynamic, the build's own prerender attempt reaches that render and the violation is a hard build failure. If a `Suspense` boundary upstream is already deferred to request time — because something else inside it, or above it, reads `cookies()`/`headers()`/`connection()` outside a cache scope — the render inside that boundary never happens during the build at all, so the violation isn't evaluated until a real request resumes the deferred render. **Add one outer dynamic API above a `Suspense` boundary, and every enforcement point inside that boundary that depends on rendering to be caught — not only the one the API was added for — stops running at build time and starts running only when a request resumes it.**

| # | Probe | Phase | Build | Runtime | Silent? |
| --- | --- | --- | --- | --- | --- |
| 1 | `'use cache'` on a non-async function | before render (fixed) | **fails** — `"use cache" functions must be async functions.` | n/a | no |
| 2 | `cacheLife()` at module scope | before render (fixed) | **fails** — `` `cacheLife()` can only be called inside a "use cache" function. `` | n/a | no |
| 3a | `cookies()` inside a cached scope, called from a route with no outer dynamic API of its own | during render — subtree prerendered | **fails** — `Route … used cookies() inside "use cache". Accessing Dynamic data sources inside a cache scope is not supported.`, with a source frame naming the exact line | n/a | no |
| 3b | the identical violation, called from a route already dynamic for an unrelated reason | during render — subtree deferred | passes — the unrelated dynamic API already skips the build-time prerender before it reaches the cached call | **fails** — same error, carried as a `digest` inside the streamed RSC payload; the HTTP status is 200 | no — loud, but only once the route actually runs |
| 4a | `connection()` inside a cached scope, called from a route with no outer dynamic API of its own | during render — subtree prerendered | **fails** — `Route … used connection() inside "use cache" … this function is not allowed in this scope.` | n/a | no |
| 4b | the identical violation, called from a route already dynamic for an unrelated reason | during render — subtree deferred | passes — same mechanism as 3b | **fails** — same error, carried as a `digest`; HTTP status 200 | no — loud, but only once the route actually runs |
| 5 | `new Date()` inside a cached scope | n/a — not a violation | passes | passes — same timestamp returned 2s apart | **yes** — freezes at cache-entry creation; nothing in the response marks it stale |
| 6 | `useState` in a Server Component | before render (fixed) | **fails** — `You're importing a module that depends on useState into a React Server Component module. … mark the file … with "use client".` | n/a | no |
| 7 | `onClick` on an element in a Server Component | during render — subtree prerendered; **untested with an outer dynamic API, but predicted by the mechanism** | **fails** — `Event handlers cannot be passed to Client Component props.` | n/a | no |
| 8 | Server Component imported into a Client Component | mixed — spans both categories depending on the variant, see note below | **depends — see note below the table** | n/a | **partially** — the no-server-API case is fully silent |
| 9 | a function passed as a prop across the client boundary | during render — subtree prerendered; **untested with an outer dynamic API, but predicted by the mechanism** | **fails** — message depends on the prop's name (see note below the table) | n/a | no |
| 10a | a class instance passed as a prop across the boundary, called from a route with no outer dynamic API of its own | during render — subtree prerendered | **fails** — `Only plain objects, and a few built-ins, can be passed to Client Components from Server Components. Classes or null prototypes are not supported.` | n/a | **no — measured, corrects an earlier assumption in this article and in `foundations/server-and-client-components`** |
| 10b | the identical violation, called from a route already dynamic for an unrelated reason | during render — subtree deferred | passes — same mechanism as 3b/4b | **fails** — same defect, carried as a `digest`; HTTP status 200 | no — loud, but only once the route actually runs |
| 11 | a non-async export in a `'use server'` file | before render (fixed) | **fails** — `Server Actions must be async functions.` | n/a | no |

**Probes 3, 4, and 10 confirm the during-render category is real, and it isn't specific to `'use cache'`.** Each was tested twice: once from a route with no dynamic API of its own (3a, 4a, 10a — a hard build failure), and once from a route already dynamic for an unrelated reason, in the same shape as `app/leak-a` (3b, 4b, 10b — build passes, the identical violation surfaces only at request time). The three violations have nothing in common except that all three are checks that only run when the code holding them actually executes: two are forbidden-API checks inside a cache scope, one is a React serialization check at the client boundary. All three moved from a hard build failure to a runtime-only failure the same way, for the same reason — a `Suspense` boundary upstream was already deferred to request time by an unrelated dynamic API, so the build's prerender attempt never reached any of them. **The mechanism is Suspense deferral, full stop — not a property of `'use cache'`, and not a property of the client boundary.** Whatever is inside a deferred boundary doesn't run at build time, so whatever would have failed inside it doesn't fail at build time either.

**Probes 7 and 9 are marked untested-but-predicted, not unknown.** Both are caught at the identical build step as 3a/4a/10a — "Generating static pages," when React tries to render the tree and, for 9, serialize a prop across the client boundary. Nothing about that check distinguishes an event handler or a named function from a class instance; it fires at the same point in the same render regardless of what's being serialized. The same outer-`cookies()`-plus-`Suspense` wrapper that turned 3a/4a/10a into their b-variants should turn these into build-passing, runtime-only failures too — that is a prediction from the mechanism above, not a measurement, and this matrix says so rather than guessing silently.

**Probe 8 doesn't collapse to one verdict, and doesn't fit either category cleanly — which is itself informative.** Three variants were run: a component doing uncached, unsuspended data access fails with the same generic `blocking-prerender-dynamic` error any such route gets, regardless of the client boundary — a during-render failure, same category as 3/4/7/9/10. A component with no server-only content at all **builds clean and ships**, silently inlined into the client bundle with no error and no warning — caught nowhere, in either category. A component using a genuinely server-only API (`next/headers`) fails with a specific "only available in Server Components" error naming the API — a before-render failure, same category as 1/2/6/11, since the Turbopack import-graph check catches it, not a render. The rule isn't "a Server Component may not be imported into a Client Component" — there is no such check. The rule is "a module reachable from a Client Component's imports runs on the client," and which category catches the fallout depends entirely on what that module then tries to do.

**Probe 9's error message is name-sensitive, not just type-sensitive.** A function prop named like a DOM event handler (`onClick`) gets `Event handlers cannot be passed to Client Component props.` The identical function under a different name (`doThing`) gets the more general `Functions cannot be passed directly to Client Components unless you explicitly expose it by marking it with "use server".` Both are build failures when nothing upstream defers them; only the message differs.

**Probe 10 answers the question this session was run to settle: it is not silent, in either shape.** An earlier draft of this article — and of `foundations/server-and-client-components` — assumed a class instance would degrade the way a `Date` subclass or similar might: fields present, methods quietly `undefined`. It does not degrade, whether it's caught at build (10a) or deferred to request time by an unrelated dynamic API (10b): both are a loud, named failure, just at different phases. Both articles are corrected to state the failure rather than the assumed silent gap.

**Read the phase column, not just pass/fail.** A before-render rule is a rule you cannot get wrong — it fails identically no matter what the rest of the route looks like. A during-render rule is conditional: it is a build guarantee only for as long as nothing upstream already defers the render it lives in, and a route that grows an unrelated `cookies()` call above an existing `Suspense` boundary can silently convert every during-render rule inside that boundary from a build failure into a production-only landmine, with nothing announcing that the safety net moved. A rule enforced nowhere — probe 5, and the no-server-API half of probe 8 — is one only review will catch.

---

## Walkthrough — the four scopes, correct

<!-- extract: demos/next-lab/lib/billing.ts#getUsage -->
```ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

// uid is an ARGUMENT. It is therefore in the compiler-derived key, which
// is the entire difference between a per-user entry and a shared one.
export async function getUsage(uid: string) {
  'use cache'
  cacheLife('minutes')
  cacheTag(`usage:${uid}`)
  return db.usage.forUser(uid)
}
```

Cached: async, identity taken as an argument, lifetime and tag declared.

<!-- extract: demos/next-lab/app/dashboard/page.tsx -->
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

Server Components: async where useful, runtime reads placed below boundaries, client work pushed to leaves.

<!-- extract: demos/next-lab/app/products/[slug]/add-to-cart.tsx -->
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

Client: state at the leaf, and the reason written down.

<!-- extract: demos/next-lab/app/products/[slug]/actions.ts -->
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

Server Function: async, and the authorization note where the check belongs.

### And the four violations

<!-- extract: demos/next-lab/antipatterns/non-async-cached-fn.ts -->
```ts
// antipattern: a 'use cache' function that isn't async. The directive requires
// it — there is no synchronous cache entry, because a cache read is always at
// least one await away.
// fails: build
export function getNonAsync() {
  'use cache'
  return 42
}
```

<!-- extract: demos/next-lab/antipatterns/hooks-in-server-component.tsx -->
```tsx
// antipattern: a hook called in a Server Component with no 'use client'. There
// is no client instance for useState to attach to — this isn't a lint rule
// being strict, it is a real absence.
// fails: build
import { useState } from 'react'

export function Counter() {
  const [count] = useState(0)
  return <p>{count}</p>
}
```

<!-- extract: demos/next-lab/antipatterns/imported-server-component.tsx -->
```tsx
// antipattern: a directive-less component that reads a server-only API,
// reached through a Client Component's import graph. The import itself
// doesn't error — it silently reclassifies this module as client code — but
// next/headers has no client-side implementation, so the build fails the
// moment the reclassified module tries to use it.
// fails: build
import { cookies } from 'next/headers'

export async function AccountBadge() {
  const store = await cookies()
  return <span>{store.get('plan')?.value ?? 'free'}</span>
}
```

<!-- extract: demos/next-lab/antipatterns/class-instance-prop.tsx -->
```tsx
// antipattern: a class instance passed as a prop from a Server Component to a
// Client Component. Measured (article 8's enforcement matrix, probe 10): this
// is a build-time prerender error, not a silent shape with missing methods.
// fails: build
export class Widget {
  constructor(public name: string) {}
  getName() {
    return this.name
  }
}
```

Each carries a `// fails:` line recording where it was caught. Those lines are measurements, not predictions.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 2, 8, 14, 17.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| Where the caching rules live | In your head — `unstable_cache` took a key array and trusted you to fill it | In the compiler — the key is derived, so the scope's contents become a correctness constraint | Key construction moved from author discipline to static analysis, which is why a cached scope now *forbids* things rather than merely producing a bad key. |
| Reading the request in cached code | Legal — `unstable_cache` had no opinion; you simply got a stale result | Rejected at request time | The framework acquired a notion of what a cache scope may depend on, and enforces it rather than letting the mistake become a data bug. |
| Server/Client rules | Same module-graph rule, same serialization constraint | Unchanged | **No mechanism change — stable since v13.** What moved is the caching scope beside them. |
| Server Function surface | `'use server'` marked actions | Same, plus file-level `'use cache'` exports as a second callable category | A second kind of server reference gained a wire representation, so "what can a Client Component call" has two answers now. |
| Finding out you broke a rule | Mostly runtime, mostly in production | A mix of build errors, request-time errors, and gaps — see the matrix | Enforcement moved earlier, unevenly. The uneven part is why the matrix exists. |

---

## Real-world patterns

**Write the reason next to the boundary.** `'use client' // needs useState for the toggle` costs one line and makes the boundary reviewable. An unexplained boundary is one nobody will dare move.

**Map at the boundary, deliberately.** ORM models, `Decimal`, custom value types: convert to plain objects before they cross. Do it in one place per entity rather than at each call site.

**Authorize in the function, never in the caller.** Every Server Function is reachable by anyone who has its id. Treat each one as a route handler that happens to have nice ergonomics.

**Read identity outside, pass it in — and make sure the argument identifies the data.** Passing an argument is not sufficient if every user passes the same one.

**Lean on build-time enforcement, staff the rest — and don't assume a during-render rule stays build-time.** Where the matrix says *before render*, the tooling is the review, unconditionally. Where it says *during render*, that guarantee holds only as long as nothing upstream defers the `Suspense` boundary the violation lives in — add one unrelated `cookies()` call above it, and the rule silently moves off the build gate and onto the checklist, with nothing in the diff announcing the move. Where the matrix says *runtime* or *silent* outright, it was never a build gate to begin with.

---

## Common mistakes

**1. Treating the cached-scope rules as style.** They are key-correctness constraints. A violation is a wrong answer, not an untidy one.

**2. Expecting the framework to catch identity in a cached scope.** It catches `cookies()`. It cannot catch a module-level variable read at execution time, and it cannot catch an argument that is the same for every user.

**3. Reading a cached timestamp as "now."** It is the entry's creation time and nothing in the output says so.

**4. Importing a Server Component into a Client Component.** Nothing stops you at that line — the import silently reclassifies the module as client code (matrix probe 8). The failure, if there is one, shows up later and elsewhere: a Node-only API it uses, or an unsuspended data call. Pass it as `children` instead, and it stays a Server Component.

**5. Passing a class instance across the boundary.** This is a hard build failure (`Classes or null prototypes are not supported`), not a silent shape where fields arrive and methods don't — matrix probe 10, measured. Map to a plain object before the boundary.

**6. Hiding a button and calling it authorization.** The endpoint remains.

**7. `useState` in a Server Component.** There is no client instance. The error is not a lint rule being strict.

**8. Assuming `'use client'` means client-only.** It renders on the server first. Device-specific values start null and arrive after hydration.

---

## Exercises

**1. Predict the matrix.** Before reading it, write down for each of the eleven probes whether you expect it to be caught before render or during render — and, for anything you marked "during render," whether you expect that answer to change if an unrelated `cookies()` call gets added above it. Score yourself. The rows you got wrong are the rules you are currently relying on luck for.

**2. Find a silent one in your own code.** The genuinely silent case in this matrix isn't the class instance — that one is a loud build failure. It's a directive-less component reachable from a `'use client'` import: it becomes client code with no error and no marker anywhere in the source. Search your client components' imports for a file with no `'use client'` or `'use server'` of its own, and check whether you meant for it to run in the browser.

*Hint: check `page_client-reference-manifest.js` for the route — a silently reclassified module won't appear as its own entry; its code is inlined into whichever Client Component imported it.*

**3. Audit one Server Function.** Take one from an app you have and ask what happens if a stranger calls it with valid-looking arguments. If the answer depends on which UI called it, you have found a real one.

---

## Summary

- Four scopes, two generating facts: **the prerender has no request**, and **the client boundary is a wire**.
- Cached scopes may not read the request, may not be sync, and are keyed by their arguments.
- Server Components have no client lifecycle; Client Components render on the server first; Server Functions are public endpoints.
- Sync IO is permitted in a cached scope and forbidden outside one, because a cached value's staleness is bounded and a prerendered one's is not.
- **The rules are not equally enforced.** Build-time rules are free; request-time rules ship if the path isn't exercised; silent ones need review.
- A cached timestamp is the entry's creation time, and the looser the lifetime the worse the lie.

---

## See also

- [`foundations/server-and-client-components`](./server-and-client-components.md) — the module-graph rule in full
- [`foundations/build-time-request-time-and-the-client`](./build-time-request-time-and-the-client.md) — the suspendable/non-suspendable split
- [`caching/cache-components-model`](../caching/cache-components-model.md) — why cached scopes have constraints at all
- [`caching/use-cache-directive`](../caching/use-cache-directive.md) — what enters a derived key
- [`mutations/server-function-security`](../mutations/server-function-security.md) — the authorization rule at length

---

## References

- Next.js — Directives: `use cache`, `use server`, `use client`
- Next.js — Guides: Migrating to Cache Components
- Next.js — Functions: `connection`, `cacheLife`, `cacheTag`, `updateTag`
- React — Server Components, `'use client'`, `use`

---

## Demo source

`demos/next-lab/lib/billing.ts`, `demos/next-lab/app/dashboard/`, `demos/next-lab/app/products/[slug]/`, the four files in `demos/next-lab/antipatterns/` named above, and `demos/next-lab/observations/enforcement-matrix.txt`.

> **Verification status.** Verified against `next@16.3.0`. The enforcement matrix is measured in full for every row except two: probes 7 and 9's during-render behavior when an outer dynamic API defers the boundary is a prediction from the mechanism measured on probes 3, 4, and 10, not its own measurement, and is labeled as such rather than presented as fact. Probe 8 and probe 9 were each re-run with an extra variant beyond the original eleven, because the first pass surfaced a generic error unrelated to the thing being tested; both are reported in full under the matrix. Probes 3, 4, and 10 were each re-run in two shapes — a route with no outer dynamic API of its own, and a route already dynamic for an unrelated reason — after the original single-row probe 3 turned out to describe the calling route rather than the violation; all three confirm the same Suspense-deferral mechanism, across two forbidden-API checks and one client-boundary serialization check, which is why the matrix states the mechanism as general rather than specific to `'use cache'`. The bounded-staleness unification of the two sync-IO results is marked in-text as **my inference** from measured behavior rather than documented rationale. **Probe 10 was the load-bearing row, and it resolved:** a class instance crossing the client boundary is a hard build failure in both shapes, not silent. `foundations/server-and-client-components` overclaimed a silent degradation and has been corrected in the same change that landed this article. Every code block here is extracted; the matrix was authored from measurements by the session that ran them, not by the article's author.
