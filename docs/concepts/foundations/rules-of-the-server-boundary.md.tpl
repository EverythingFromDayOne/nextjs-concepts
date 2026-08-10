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
- **May not be imported by a Client Component.** It may be passed to one as `children` or an element prop.

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

{ENFORCEMENT_MATRIX}

**Read the right-hand column, not the left.** A rule enforced at build time is a rule you cannot get wrong. A rule enforced at request time is one that ships if the failing path isn't exercised — which is how a code path only signed-in users reach fails first in production. A rule enforced nowhere is one only review will catch.

---

## Walkthrough — the four scopes, correct

{EXTRACT:demos/next-lab/lib/billing.ts#getUsage}

Cached: async, identity taken as an argument, lifetime and tag declared.

{EXTRACT:demos/next-lab/app/dashboard/page.tsx}

Server Components: async where useful, runtime reads placed below boundaries, client work pushed to leaves.

{EXTRACT:demos/next-lab/app/products/[slug]/add-to-cart.tsx}

Client: state at the leaf, and the reason written down.

{EXTRACT:demos/next-lab/app/products/[slug]/actions.ts}

Server Function: async, and the authorization note where the check belongs.

### And the four violations

{EXTRACT:demos/next-lab/antipatterns/non-async-cached-fn.ts}

{EXTRACT:demos/next-lab/antipatterns/hooks-in-server-component.tsx}

{EXTRACT:demos/next-lab/antipatterns/imported-server-component.tsx}

{EXTRACT:demos/next-lab/antipatterns/class-instance-prop.tsx}

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

**Lean on build-time enforcement, staff the rest.** Where the matrix says *build*, the tooling is the review. Where it says *runtime* or *silent*, that rule belongs on a checklist, because nothing will stop it reaching production.

---

## Common mistakes

**1. Treating the cached-scope rules as style.** They are key-correctness constraints. A violation is a wrong answer, not an untidy one.

**2. Expecting the framework to catch identity in a cached scope.** It catches `cookies()`. It cannot catch a module-level variable read at execution time, and it cannot catch an argument that is the same for every user.

**3. Reading a cached timestamp as "now."** It is the entry's creation time and nothing in the output says so.

**4. Importing a Server Component into a Client Component.** The import is what moves it. Pass it as `children`.

**5. Passing a class instance across the boundary.** See the matrix row — the enforcement here is the one to check before you rely on it.

**6. Hiding a button and calling it authorization.** The endpoint remains.

**7. `useState` in a Server Component.** There is no client instance. The error is not a lint rule being strict.

**8. Assuming `'use client'` means client-only.** It renders on the server first. Device-specific values start null and arrive after hydration.

---

## Exercises

**1. Predict the matrix.** Before reading it, write down for each of the eleven probes whether you expect build, runtime, or silent. Score yourself. The rows you got wrong are the rules you are currently relying on luck for.

**2. Find a silent one in your own code.** Search for props crossing a client boundary that are not plain objects — model instances, dates inside class wrappers, anything with methods. Check what the client actually receives.

*Hint: log `Object.getPrototypeOf(prop)` on the client and see what you get.*

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

> **Verification status.** Verified against `next@16.3.0`. The enforcement matrix is measured in full — every row from a build, and a request where the build succeeded. The bounded-staleness unification of the two sync-IO results is marked in-text as **my inference** from measured behavior rather than documented rationale. **One row is load-bearing for two other articles:** if a class instance crossing the client boundary is *not* silent, articles 2 and this one both overclaim and need correcting. Every code block here is extracted; the matrix was authored from measurements by the session that ran them, not by the article's author.
