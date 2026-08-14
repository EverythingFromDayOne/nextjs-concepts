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

{EXTRACT:demos/next-lab/observations/leak-fix-proof.txt}

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

{EXTRACT:demos/next-lab/lib/billing-leak-a.ts}

This does not leak, because it does not run:

{EXTRACT:demos/next-lab/observations/leak-a-runtime-error.txt}

**But look at when it fails, because it decides whether you find out.** Enforcement follows execution: this check only fires when the cached call is actually rendered. On a route that would prerender, that's at build — a hard failure with a source frame naming the line. On a route where something *else* already read a dynamic API, the prerender is skipped, and the violation waits for a real request.

So the route that reads cookies "correctly" at the top is the route that hides this one inside. Doing one thing right masks the other thing being wrong. Full mechanism in [`rules-of-the-server-boundary`](../../concepts/foundations/rules-of-the-server-boundary.md).

### Step 2 — the version that leaks silently

No Next.js API is touched, so no guard fires:

{EXTRACT:demos/next-lab/lib/billing-leak-b.ts}

The module-level variable is set by an uncached caller before the cached function runs. It is read at *execution* time, so it cannot be in a key derived from arguments. Alice's dashboard is stored; Bob's request matches the same key and gets it.

Nothing is wrong with this code by any rule the framework can check. It is a wrong belief about valid code.

### Step 3 — the version that leaks *with* an argument

The one that catches careful people. Identity is read outside the cached scope and an argument is passed in — exactly what the guidance says:

{EXTRACT:demos/next-lab/lib/billing-leak-c.ts}

The argument is in the key. The key is honest. **Every signed-in user passes the same argument**, so every signed-in user shares one entry.

Which sharpens the rule from *read outside, pass in* to:

> **The argument must identify the data.** Passing an argument is not the point; passing one that distinguishes the result is.

### Step 4 — the fix

{EXTRACT:demos/next-lab/app/leak-fixed/page.tsx}

Three things are doing work here, and the directive is not one of them:

- `uid` is read **outside** every cached scope, where a request exists.
- It is passed as an **argument**, so it enters the compiler-derived key.
- It **identifies the data** — one entry per user, which is what you wanted when you reached for a cache.

### Step 5 — the beat people stop before

Correct keying gives every user their own entry. It does not decide whether they were allowed to ask.

{EXTRACT:demos/next-lab/lib/authz.ts}

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

{EXTRACT:demos/next-lab/observations/private-cache-probe.txt#L2-L21}

**Nothing in the tooling can tell you this happened, either.** `next build`'s route table and `next dev`'s server log were compared directly between a leaking route and its fix — measured, not assumed:

{EXTRACT:demos/next-lab/observations/private-cache-probe.txt#L23-L36}

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
