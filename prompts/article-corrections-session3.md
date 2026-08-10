# Article corrections from session 3 measurements

Six discrepancies. Two invalidate claims, three fix methodology, one is a null result worth chasing. Apply in order; §1 is the substantive one.

---

## 1. The cross-user leak — rewrite, don't patch

**What I claimed:** reading identity inside a `'use cache'` scope silently leaks user A's data to user B.

**What the demo shows:** the naive form doesn't leak — it throws. `Route /leak-a used cookies() inside "use cache". Accessing Dynamic data sources inside a cache scope is not supported.` The framework guards the obvious mistake.

**What actually leaks:** vectors B and C, both confirmed — alice's `data-uid` returned to bob.

The corrected story is sharper than the one I wrote, because the two real vectors evade *different* things.

### 1a. Replace article 6 → "Cache keys are derived, not written" → the code pair

The current ❌/✅ pair shows vector A as a leak. It is not. Replace the whole passage after "The dangerous one:" with:

> **The dangerous one:** anything that is *not* an argument is not in the key. A cached function has no idea who is asking.
>
> Next.js guards the obvious version of this. Reading `cookies()` inside a cached scope throws:
>
> ```
> Route /dashboard used cookies() inside "use cache".
> Accessing Dynamic data sources inside a cache scope is not supported.
> ```
>
> Note **when** it throws: at request time, not at build. Whether a dynamic API is reachable through a call chain isn't statically decidable, so the check has to be dynamic — which means a path only exercised for signed-in users won't fail until a signed-in user hits it. A build that goes green is not evidence that no cached scope reads the request.
>
> The vectors that do leak evade the key rather than the guard.
>
> **Ambient module state.** No Next API is touched, so nothing fires — and the value is read at execution time, so it cannot be in the key:
>
> ```ts
> let lastSeenUid = 'anonymous'          // set by an uncached caller
>
> export async function getDashboard() {
>   'use cache'
>   cacheLife('minutes')
>   return db.usage.forUser(lastSeenUid) // stored under a key that ignores it
> }
> ```
>
> Alice's dashboard is stored. Bob's request matches the same key and receives it.
>
> **A key that doesn't discriminate.** Here the argument *is* in the key. It is simply the same argument for every signed-in user:
>
> ```ts
> export async function getDashboard(scope: 'signed-in' | 'anonymous') {
>   'use cache'
>   const uid = scope === 'signed-in' ? currentUser() : null
>   return db.usage.forUser(uid)
> }
> ```
>
> The guard is satisfied. The key is honest. The result is still wrong.
>
> So the rule is not merely "read outside, pass in" — it is **the argument must identify the data**. Passing `scope` is passing an argument, and it leaks anyway.

### 1b. Tighten the key description everywhere

I wrote that keys derive from "the build ID, the serialized arguments, and the values the function closes over." The third term is misleading — vector B *is* a lexical capture, and it isn't in the key, because it's read when the function runs rather than bound when the entry is created.

Replace with, in article 6 §"How it works", article 1 §"'use cache' moves work back into the shell", and article 6's Summary:

> derived from the build ID and the serialized arguments. **Anything read from ambient state at execution time cannot be in the key** — and the framework can only stop you when that ambient state is a Next API it recognizes.

### 1c. Article 6 → Common mistakes #3

Replace with:

> **3. Assuming the framework will catch identity in a cached scope.** It catches `cookies()` — at request time, not build time. It cannot catch a module-level variable set by the caller, and it cannot catch an argument that is the same for every user. The key contains the arguments; it does not contain who asked. This is the only mistake on this list that is a security incident.

### 1d. Article 6 → Exercise 3

Replace "Move the `cookies()` read inside `getUsage`" with:

> **3. Build the leak, then fix it.** Add a module-level `let lastSeenUid` to `lib/billing.ts`, set it from the uncached `Usage` component, and read it inside the cached function instead of taking `uid` as an argument. Build, start, then request the page twice with different `uid` cookies.
>
> *Hint: `UsageChart` renders `data-uid`. If both requests return the same one, you have reproduced it. Then try the same thing with `cookies()` inside the cached function and note that you get an error instead — the framework catches one form and not the other, and knowing which is which is the point.*

### 1e. Article 1 → Common mistakes #7

Same correction: the example shown is the *caught* form. Swap it for the module-capture form and keep the one-line rule.

### 1f. Recipe #2 — respec

`caching/user-a-sees-user-b-data` now has a confirmed reproduction and a better arc:

1. The symptom, with the `data-uid` diff between two cookie values.
2. Why it escaped QA — one user in dev, and the guard that *does* exist made everyone assume the whole class was covered.
3. Fix arc: name the mechanism (the key holds arguments, not the request) → show the caught form and why it's caught at request time rather than build → show the two uncaught forms → the real rule, *the argument must identify the data* → an authorization check outside every cached scope, because a cache hit must never be a way to skip a permission check.
4. When NOT to use `'use cache: private'` as the fix.

Demo source: `lib/billing-leak-{a,b,c}.ts` and `app/leak-{a,b,c}/` — **retain all six files.**

---

## 2. `curl` does not show you the shell — fix every "verify the loop"

`curl` follows the stream to completion, so the skeleton *and* the final content both appear in the body. So do view-source and DevTools. Every instruction I wrote of the form "view source, don't trust DevTools" is wrong: none of those observe the prerender.

**The prerender artifact is the file on disk:** `.next/server/app/<route>.html`. That is what you inspect to answer "is this in the shell." It's how the alerts measurement in §8.5 worked, and it should have been the method throughout.

Fix in all three articles' walkthroughs, and add to roadmap §5 measurement standard:

> **Shell claims are verified against `.next/server/app/<route>.html`, never against a response body.** A streamed response contains both the fallback and the resolved content, so `curl`, view-source, and DevTools all show a completed stream rather than the shell. The build artifact is the only place the shell exists in isolation.

## 3. There is no First Load JS column in 16.3 — article 2 needs a real method

The Turbopack build table doesn't print it, so article 2's stage 1→3 comparison has no measurement path as written.

Replace with a stated method, and use the same one in article 33 (`performance/the-client-bundle`):

> Sum the byte sizes of the chunk files a route lists in `.next/app-build-manifest.json`. Report the number with the method inline, or use `@next/bundle-analyzer` when the question is *which module* rather than *how much*.

Then re-measure stages 1–3 and put real numbers in the article. If the three stages can't be given comparable numbers this way, say so and drop the numeric claim rather than hedging it.

**Also note in article 2:** stages 1–3 live in `_stages/`, a private folder, so they are not routes and will never appear in the build table. That's a feature — it's article 23's convention demonstrated in place — but the article must say it, or a reader will go looking for missing rows.

## 4. Path corrections

Update the "Demo source" footers:

| Article says | Actual |
| --- | --- |
| `app/dashboard/page.next15.tsx` | `legacy/dashboard-page.next15.tsx` |
| `page.stage1.tsx` … `page.stage4.tsx` | `app/catalog/_stages/stage{1,2,3}-*.tsx`; stage 4 is `app/catalog/page.tsx` |

## 5. Confirmed — promote from claim to measurement

Two article claims are now observed. Replace the hedged wording with the recorded output and mark them measured in the Verification status blocks.

- **Sync IO.** `Error: Route "/products/[slug]": Next.js encountered the unstable value new Date() while prerendering.` Quote it; the fix list it prints includes `await connection()`, which is worth showing since the error teaches the mechanism.
- **Lifetime moves placement.** `cacheLife('minutes')` → alert present in `.next/server/app/dashboard.html`; `'seconds'` → absent from the prerender, present only in the stream. This was the sharpest paragraph in article 6 and it is now measured rather than asserted.

**One artifact worth a sentence in article 10 (`cache-lifetimes`):** the build table reported the route as `1d / 1w` — the *plans* lifetime dominating a route-level summary while individual entries carry their own. A route-level revalidate/expire column is a leftover of route-level thinking, and reading it as "the lifetime of this page" will mislead you.

## 6. Null result — construct an insight deliberately

All three routes returned 200 with no insight lines, which is consistent: they're correctly built, so there's nothing to flag. But it means the claim "insights exist and never appear in the HTTP response" is still **unobserved**, and it's load-bearing in article 6 and in roadmap §5.

Build one on purpose. Candidates, cheapest first:

- A route with `export const instant = false`.
- A route whose shell is technically valid but empty — every child inside one `<Suspense>` with a `null` fallback.

Add it as `app/insight-probe/`, run `next dev`, and record whether an insight appears and where. If none of these produce one, say so — an unreproducible claim gets removed, not hedged. This is also the concrete reason to finish wiring the DevTools MCP.

---

## Acceptance

- [ ] §1a–1f applied; the caught-vs-uncaught distinction is the article's spine, not a footnote
- [ ] Key description tightened in all three places
- [ ] All shell-verification steps point at `.next/server/app/<route>.html`; roadmap §5 updated
- [ ] Article 2 has a real bundle-measurement method and real numbers, or no numeric claim
- [ ] Demo-source paths corrected in all three articles
- [ ] Sync-IO and lifetime claims quoted from recorded output, marked measured
- [ ] `app/insight-probe/` built; result recorded either way
- [ ] Six leak files retained as recipe #2's demo source
