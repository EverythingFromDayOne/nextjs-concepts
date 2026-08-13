# Cursor — session 11: recipe #2 (`caching/user-a-sees-user-b-data`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session11-recipe2-demos.md
Model:    channel default
Needs:    pnpm build · pnpm start + curl · python3
```

The first recipe. Opens the `caching/` track and is the first use of `docs/templates/RECIPE_TEMPLATE.md`, which was scaffolded in session 1 and has never been exercised — **report anything about that template that doesn't fit a real recipe.**

Most of the demo material already exists: `lib/billing-leak-{a,b,c}.ts`, `app/leak-{a,b,c}/`, and the captures in `observations/`. This session builds the **fix** side and probes one alternative.

---

## 1. `app/leak-fixed/` — the corrected shape

The recipe needs the fix demonstrated as running code, not described. Reuse `getUsage` from `lib/billing.ts` — it already takes `uid` as an argument.

**`demos/next-lab/app/leak-fixed/page.tsx`**

```tsx
import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { getUsage } from '@/lib/billing'
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
  return <UsageChart usage={await getUsage(uid)} />
}
```

## 2. `lib/authz.ts` — the check that must live outside the cache

The recipe's last beat: passing the right argument is necessary and not sufficient. A cache hit must never be a way to skip a permission check.

```ts
import { db } from './db'

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

Wire it into `leak-fixed`'s `Usage` component: read identity, authorize, *then* call the cached read.

## 3. EXPERIMENT A — prove the fix, both directions

```bash
pnpm build && pnpm start
```

Capture into `observations/leak-fix-proof.txt`:

```bash
# broken — expect the same data twice
curl -s -H 'Cookie: uid=user-alice' http://localhost:PORT/leak-b | grep data-uid
curl -s -H 'Cookie: uid=user-bob'   http://localhost:PORT/leak-b | grep data-uid

# fixed — expect different data
curl -s -H 'Cookie: uid=user-alice' http://localhost:PORT/leak-fixed | grep data-uid
curl -s -H 'Cookie: uid=user-bob'   http://localhost:PORT/leak-fixed | grep data-uid
```

Also record: does `/leak-fixed` still show `◐` in the build table? The fix should cost nothing structurally — if it changes the route's shape, that's worth knowing.

## 4. EXPERIMENT B — `'use cache: private'` as an alternative fix

**This decides a whole section of the recipe, and I can't predict it.** The docs describe `'use cache: private'` as experimental, browser-memory only, with `connection()` prohibited inside it. The obvious question a reader will have: *can I just use that instead of restructuring?*

Create `lib/billing-private.ts`:

```ts
import { cacheLife } from 'next/cache'
import { cookies } from 'next/headers'
import { db } from './db'

export async function getDashboardPrivate() {
  'use cache: private'
  cacheLife('minutes')
  const uid = (await cookies()).get('uid')?.value ?? 'anonymous'
  return db.usage.forUser(uid)
}
```

Wire it to `app/leak-private/` in the same shape as `leak-b`, then answer **all four**:

1. Does it **build**? Any flag required in `next.config.ts` beyond `cacheComponents`?
2. Does `cookies()` inside `'use cache: private'` throw the way it does inside plain `'use cache'`, or is it permitted?
3. Two `curl`s with different cookies — **does it leak?**
4. Is the response cached at all in a way you can observe from the server side, or is it purely a browser-memory mechanism with no server-side reuse?

→ `observations/private-cache-probe.txt`

**If it builds and doesn't leak**, it's a legitimate alternative and the recipe presents it as one, with its experimental status and limits stated. **If it errors, or leaks, or turns out to provide no server-side caching at all**, the recipe says so plainly and explains why restructuring is the real fix. Do not soften whichever answer comes back.

## 5. EXPERIMENT C — the detection question

A reader who suspects this bug needs a way to find it. Test the cheapest detection:

Does anything in `next build` output, the dev overlay, or the dev-server log distinguish `/leak-b` (leaks) from `/leak-fixed` (doesn't)? Build both, run both in dev, and record what — if anything — differs.

→ append to `observations/private-cache-probe.txt` under a `Detection` heading.

**A negative result is the finding here.** If nothing distinguishes them, the recipe must say that the framework cannot detect this class and the reader needs the two-cookie test as a manual check. That's more useful than implying a tool exists.

## 6. Template

`prompts/session11/user-a-sees-user-b-data.md.tpl` ships with this. Placeholders:

- `{FIX_PROOF}` — experiment A
- `{PRIVATE_CACHE_RESULT}` — experiment B, all four questions
- `{DETECTION_RESULT}` — experiment C, including a negative result

Move to `docs/recipes/caching/` as the final step. Add a row to `docs/recipes/index.md`. Ships `draft`.

---

## 7. Report on the template itself

First use of `RECIPE_TEMPLATE.md`. Answer directly:

- Did every section it mandates have something real to hold, or did any feel like filler?
- Did the recipe need a section the template doesn't have?
- Is the frontmatter (`recipe_id`, `primary_concept`, `difficulty`, `next_baseline`) sufficient?

Thirty-plus recipes follow this template. Cheaper to fix now.

---

## Acceptance

- [ ] `leak-fixed` and `authz.ts` built; authorization runs outside the cached scope
- [ ] Experiment A: all four curls captured; build-table shape recorded
- [ ] Experiment B: all four questions answered, whichever way they come out
- [ ] Experiment C: recorded, including a negative result stated as one
- [ ] All six leak files retained (`leak-{a,b,c}` libs and routes)
- [ ] Placeholders filled from `observations/`; recipe index updated; gates green
- [ ] Template feedback given
