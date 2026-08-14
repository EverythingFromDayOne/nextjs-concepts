---
recipe_id: user-a-sees-user-b-data
primary_concept: caching/use-cache-directive
difficulty: intermediate
next_baseline: "16.3.0"
verified_against: next@16.3.0
verified_on: 2026-08-13
status: draft
---

# A signed-in user sees someone else's data

> **Symptom.** A support ticket says a user's dashboard showed another account's numbers. You cannot reproduce it. It happens under load, or after a deploy, or only for the second person to hit a page. Your logs show `200`s.

---

## What you'll build

A working reproduction of a cross-user cache leak, a measured fix, and a check you can run in thirty seconds against your own app.

You'll also see why the framework catches one version of this bug and not the other two — which is the part that decides whether you're safe or just lucky.

---

## The scenario

A billing dashboard. Usage figures per account, read from the database, cached because the query is expensive and the numbers only move every few minutes.

Alice loads `/dashboard`. Her figures are computed and stored. Bob loads `/dashboard` thirty seconds later. Bob sees **Alice's** figures.

Nothing errored. Both requests returned `200`. The page rendered correctly — with the wrong data.

The measured reproduction, two requests with different session cookies:

<!-- extract: demos/next-lab/observations/leak-fix-proof.txt -->
```text
# produced: 2026-08-13; next@16.3.0; command: next build; next start; curl -H 'Cookie: uid=...' /leak-b and /leak-fixed; grep data-uid
# broken — /leak-b — expect the same data twice
curl -H 'Cookie: uid=user-alice' /leak-b  ->  data-uid="user-alice"
curl -H 'Cookie: uid=user-bob'   /leak-b  ->  data-uid="user-alice"

# fixed — /leak-fixed — expect different data
curl -H 'Cookie: uid=user-alice' /leak-fixed  ->  data-uid="user-alice"
curl -H 'Cookie: uid=user-bob'   /leak-fixed  ->  data-uid="user-bob"

# build-table shape — does the fix cost anything structurally?
route table lines mentioning /leak-* (from the same `pnpm build` above):
Route (app)                    Revalidate  Expire
├ ◐ /leak-a
├ ◐ /leak-b
├ ◐ /leak-c
├ ◐ /leak-fixed
├ ◐ /leak-private
/leak-b and /leak-fixed both show the same annotation (◐ Partial Prerender), same as /leak-a and /leak-c.
Neither carries a Revalidate/Expire pair in the table — every entry on these routes is per-request,
so nothing survives long enough to appear in the build-time prerender pass that populates those columns.
The fix is a pure keying change; it does not alter the route’s prerender shape.
```

Read the top half of that capture: two different users, identical `data-uid`. The bottom half is the same page after the fix.

### Why it happens

Under Cache Components, a `'use cache'` scope's key is **derived by the compiler from the function's arguments**. Not from the request. Not from the session. A cached function has no idea who is asking.

So the question is not "did I cache user data" — it's **"is the identity of the user in the key?"** There are three ways to get that wrong, and they fail very differently.

---

## Why it escaped QA

Four reasons, and the fourth is the one that makes this dangerous rather than merely embarrassing.

**One user in development.** You test signed in as yourself. A cache keyed on nothing still returns *your* data, correctly, every time. The bug needs two identities to appear.

**Cache misses hide it.** A cold cache serves the right data. The bug surfaces on the *second* request within a lifetime — which in dev, with hot reload evicting entries constantly, is rare.

**No error, no log line, no status code.** The response is a well-formed `200`. Nothing in your monitoring distinguishes a leak from a correct render.

**The framework catches the obvious version, which teaches you the wrong lesson.** Reading `cookies()` directly inside a cached scope is rejected. Having seen that guard fire once, it's natural to conclude the whole class is covered. It isn't — and the two forms that *do* leak are the ones the guard cannot see.

---

## Walkthrough

### Step 1 — the version that is caught

The naive form. Read the session inside the cached function:

<!-- extract: demos/next-lab/lib/billing-leak-a.ts -->
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

This does not leak, because it does not run:

<!-- extract: demos/next-lab/observations/leak-a-runtime-error.txt -->
```text
# produced: 2026-08-10; next@16.3.0; command: next start; curl -H "Cookie: uid=user-alice" /leak-a
HTTP 200 (error UI in body)
Route /leak-a used cookies() inside "use cache". Accessing Dynamic data sources inside a cache scope is not supported. This is a bug in your application.
digest: 3264027773@E831
```

**But look at when it fails, because it decides whether you find out.** Enforcement follows execution: this check only fires when the cached call is actually rendered. On a route that would prerender, that's at build — a hard failure with a source frame naming the line. On a route where something *else* already read a dynamic API, the prerender is skipped, and the violation waits for a real request.

So the route that reads cookies "correctly" at the top is the route that hides this one inside. Doing one thing right masks the other thing being wrong. Full mechanism in [`rules-of-the-server-boundary`](../../concepts/foundations/rules-of-the-server-boundary.md).

### Step 2 — the version that leaks silently

No Next.js API is touched, so no guard fires:

<!-- extract: demos/next-lab/lib/billing-leak-b.ts -->
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

The module-level variable is set by an uncached caller before the cached function runs. It is read at *execution* time, so it cannot be in a key derived from arguments. Alice's dashboard is stored; Bob's request matches the same key and gets it.

Nothing is wrong with this code by any rule the framework can check. It is a wrong belief about valid code.

### Step 3 — the version that leaks *with* an argument

The one that catches careful people. Identity is read outside the cached scope and an argument is passed in — exactly what the guidance says:

<!-- extract: demos/next-lab/lib/billing-leak-c.ts -->
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

The argument is in the key. The key is honest. **Every signed-in user passes the same argument**, so every signed-in user shares one entry.

Which sharpens the rule from *read outside, pass in* to:

> **The argument must identify the data.** Passing an argument is not the point; passing one that distinguishes the result is.

### Step 4 — the fix

<!-- extract: demos/next-lab/app/leak-fixed/page.tsx -->
```tsx
import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { getUsage } from '@/lib/billing'
import { assertCanViewUsage } from '@/lib/authz'
import { UsageChart } from '@/app/dashboard/parts'

export default function LeakFixedPage() {
  return (
    <main>
      <Suspense fallback={<p aria-busy="true">Loading usage…</p>}>
        <Usage />
      </Suspense>
    </main>
  )
}

async function Usage() {
  // Identity read here, outside every cached scope, and passed in as an
  // argument — so it lands in the compiler-derived key.
  const uid = (await cookies()).get('uid')?.value
  if (!uid) return <p>Sign in to see usage.</p>
  // Authorization runs on the request path, outside the cached scope it
  // guards. A cache hit is never a way to skip this.
  await assertCanViewUsage(uid, uid)
  return <UsageChart usage={await getUsage(uid)} />
}
```

Three things are doing work here, and the directive is not one of them:

- `uid` is read **outside** every cached scope, where a request exists.
- It is passed as an **argument**, so it enters the compiler-derived key.
- It **identifies the data** — one entry per user, which is what you wanted when you reached for a cache.

### Step 5 — the beat people stop before

Correct keying gives every user their own entry. It does not decide whether they were allowed to ask.

<!-- extract: demos/next-lab/lib/authz.ts -->
```ts
export class NotAuthorized extends Error {}

/**
 * Deliberately NOT cached. An authorization decision that lives inside a
 * cached scope is an authorization decision that can be replayed for
 * someone who was never authorized.
 */
export async function assertCanViewUsage(viewerUid: string, targetUid: string) {
  if (viewerUid !== targetUid) throw new NotAuthorized('not your usage')
  return true
}
```

An authorization check inside a cached scope is a decision that can be replayed for someone who was never authorized. Keep it outside, on the request path, every time — even when the data it guards is cached.

### Step 6 — verify

```bash
pnpm build && pnpm start
curl -s -H 'Cookie: uid=user-alice' http://localhost:3000/dashboard | grep data-uid
curl -s -H 'Cookie: uid=user-bob'   http://localhost:3000/dashboard | grep data-uid
```

Different values, or you still have it. Run it against a **production build** — dev's cache behaviour differs and will not reproduce this reliably.

---

## Variations

**Scoped-but-not-unique keys.** `getTeamData(teamId)` is correct until someone belongs to two teams and the wrong one is in scope. The key distinguishes teams, not viewers.

**Locale, currency, feature flags.** Anything that varies the *content* must be in the key. A flag read from ambient state inside a cached scope is step 2 wearing different clothes.

**Cached layouts.** A layout cached without user identity, rendering a user's name, leaks it into every page beneath — across routes, not just one.

**Third-party clients.** An SDK reading ambient config at call time inside a cached scope leaks the same way, and the code doing it is in `node_modules` where you won't be looking.

**`'use cache: remote'`.** Same key rules, durable storage. A leak that would have vanished on redeploy now persists across instances and deploys.

---

## What doesn't work

**Can `'use cache: private'` just replace all of this?** It's the obvious next question, and it's experimental. Measured against `app/leak-private` + `lib/billing-private.ts`, all four questions the experimental status raises:

<!-- extract: demos/next-lab/observations/private-cache-probe.txt#L2-L21 -->
```text
## Experiment B — 'use cache: private' as an alternative fix (app/leak-private, lib/billing-private.ts)

**Q1. Does it build? Any flag required beyond `cacheComponents`?**
PASS — same `pnpm build` as above; /leak-private appears as a listed route.
No config beyond `cacheComponents: true` (already set for the whole lab) was needed — confirmed against the bundled docs (`use-cache-private.md`, "Usage") and by this build succeeding without any additional next.config.ts flag.

**Q2. Does `cookies()` inside `'use cache: private'` throw the way it does inside plain `'use cache'`, or is it permitted?**
Permitted. curl /leak-private with Cookie uid=user-alice -> HTTP body renders normally, data-uid="user-alice". No error, no digest, no fallback-only response — unlike /leak-a (bare cookies() inside plain 'use cache'), which fails at runtime with "Route ... used cookies() inside \"use cache\"".

**Q3. Two curls with different cookies — does it leak?**
curl -H 'Cookie: uid=user-alice' /leak-private  ->  data-uid="user-alice"
curl -H 'Cookie: uid=user-bob'   /leak-private  ->  data-uid="user-bob"
Leak observed: NO — each request returned its own cookie's data.

**Q4. Is the response cached at all in a way observable server-side, or is it purely browser-memory with no server-side reuse?**
Two requests with the *same* cookie (alice), back to back: request 1 time_total=0.474982s; request 2 time_total=0.412708s.
`lib/db.ts`'s `usage.forUser` has an artificial ~400ms delay on every call. Both requests paid it (second request was NOT meaningfully faster), which means the function body — including the DB call — re-ran on the second request. Nothing was served from a server-side cache.
This matches the docs directly: the "How `use cache: remote` differs..." comparison table in `use-cache-remote.md` lists `'use cache: private'`’s "Server-side caching" as **None** — caching happens only in the browser’s memory (client-side), which curl has none of, so every request re-executes the function.

**Verdict.** It builds, `cookies()` is permitted, and it does **not** leak across users in this test — each request executes fresh with its own cookie. But it also provides **no server-side caching whatsoever**: every request re-runs the full query, unconditionally. It is not a performance optimization for this scenario at all; it is a way to let a component read request data while still being written under a cache directive. The docs frame it correctly as an escape hatch for compliance constraints or hard-to-refactor code, not a substitute for restructuring — and this recipe agrees: the real fix is Step 4 (read outside, pass the identifying argument in), not swapping the directive.
```

**Nothing in the tooling can tell you this happened, either.** `next build`'s route table and `next dev`'s server log were compared directly between a leaking route and its fix — measured, not assumed:

<!-- extract: demos/next-lab/observations/private-cache-probe.txt#L23-L36 -->
```text
## Detection — can anything distinguish /leak-b (leaks) from /leak-fixed (doesn't)?

**`next build` output.** Both routes produce identical annotations:
Route (app)                    Revalidate  Expire
├ ◐ /leak-b
├ ◐ /leak-fixed
Same `◐` mark, same (absent) Revalidate/Expire pair. The build has no way to know that one function’s key is the identity and the other’s key is nothing — both are syntactically valid `'use cache'` scopes with no argument-vs-key mismatch the compiler can see.

**`next dev` log.** Requesting each route once, with a different cookie each, produced ordinary access-log lines and nothing else:
/leak-b:     GET /leak-b 200 in 2.1s (next.js: 1564ms, application-code: 585ms)
/leak-fixed: GET /leak-fixed 200 in 639ms (next.js: 187ms, application-code: 452ms)
No warning, no diagnostic, no digest — identical shape to a normal request. Neither route emits a "blocking-prerender-dynamic"-style insight, because nothing here is a dynamic-API-outside-Suspense violation; both routes read cookies correctly and cache correctly by every rule the framework checks. The bug is a keying decision, not a rule violation.

**Finding: negative result.** Nothing in `next build` output, the dev-server log, or (by the same reasoning — there is no diagnostic to surface) the dev overlay distinguishes a leaking cache key from a correct one. The framework cannot detect this class. The only reliable check is the two-cookie manual test in Experiment A, run against a production build, on every route that caches user-scoped data.
```

---

## Trade-offs and pitfalls

**1. Don't conclude the framework has your back.** It catches one of three forms, and the two it misses are the ones that leak.

**2. A green build proves nothing here.** Whether the caught form is caught at build depends on route shape, not on the violation.

**3. Dev will not reproduce it.** One session, and hot reload evicting entries.

**4. Watch for closures over request-scoped values.** A cached function closing over anything set per-request is step 2, however it's spelled.

**5. Per-user cache entries multiply.** One entry per user is correct and it is also N entries. For data that isn't expensive to compute, streaming it uncached is often the better answer.

**6. Tags need the same discipline.** `cacheTag('usage')` invalidates everyone's. `cacheTag(\`usage:\${uid}\`)` is what you meant.

**7. Authorize outside the cache, always.** A cache hit must never be a path that skips a permission check.

**8. Audit shared layouts first.** Highest blast radius, lowest visibility.

**9. Mind the deploy boundary.** `'use cache'` entries are build-ID-keyed and in-memory, so a leak may vanish on deploy and look fixed. It isn't.

**10. Beware "it only happened once."** Under this failure mode, once is the observable part of a window.

**11. `revalidateTag` doesn't fix keying.** Invalidating an entry that shouldn't exist just means it gets rebuilt wrong.

### When NOT to use this fix

If the data is **cheap to fetch and genuinely per-user**, don't cache it at all. Stream it inside `<Suspense>` and skip the entire class of bug. Per-user cache entries are worth their risk when the underlying query is expensive and reused across several requests by the *same* user — a dashboard someone refreshes, a report they page through. For a value read once per session, the cache is buying you almost nothing and charging you a security surface.

And if the shape you actually want is "same for everyone, computed once," the fix is not a per-user key — it's removing the user from the data.

---

## Verify the loop

1. Grep for `'use cache'` in your app. For each one, ask what's in the key.
2. For each, ask: **does the argument distinguish the result?** Not "is there an argument."
3. Look for reads of ambient state inside those scopes — module variables, singletons, SDK config, anything not passed in.
4. Two-cookie test against a production build on every route that renders user data.
5. Confirm every authorization check sits outside a cached scope.
6. Check shared layouts before leaf pages.

---

## See also

- [`caching/use-cache-directive`](../../concepts/caching/use-cache-directive.md) — what enters a compiler-derived key
- [`caching/cache-components-model`](../../concepts/caching/cache-components-model.md) — why the keying rules exist
- [`data/runtime-data-and-cached-scopes`](../../concepts/data/runtime-data-and-cached-scopes.md) — read outside, pass in
- [`foundations/rules-of-the-server-boundary`](../../concepts/foundations/rules-of-the-server-boundary.md) — enforcement follows execution
- [`caching/private-and-remote-caches`](../../concepts/caching/private-and-remote-caches.md) — the three directives compared
- [`mutations/server-function-security`](../../concepts/mutations/server-function-security.md) — authorization at the endpoint

---

## References

- Next.js — Directives: `use cache`, `use cache: private`
- Next.js — Functions: `cacheLife`, `cacheTag`, `connection`
- Next.js — Guides: Migrating to Cache Components
- Next.js — Messages: `next-request-in-use-cache`

---

## Demo source

`demos/next-lab/lib/billing-leak-{a,b,c}.ts`, `demos/next-lab/lib/billing.ts`, `demos/next-lab/lib/authz.ts`, `demos/next-lab/lib/billing-private.ts`, `demos/next-lab/app/leak-{a,b,c}/`, `demos/next-lab/app/leak-fixed/`, `demos/next-lab/app/leak-private/`, and the capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0`. All three vectors were measured in session 7, not reasoned from documentation — and the measurement **corrected this recipe's original premise**, which assumed the naive `cookies()`-in-cache form leaked silently. It does not; it is rejected. The two forms that do leak evade the guard by different means, and that distinction is now the recipe's spine. The phase-dependence of the caught form was measured separately. Whether `'use cache: private'` is a viable alternative, and whether anything in the tooling can detect this class at all, are measured in this session — including the possibility that the detection answer is *nothing*. Every code block and capture is extracted.
