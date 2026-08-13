# Cursor — session 10: article 3 (`foundations/file-conventions-and-the-route-tree`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session10-article3-demos.md
Model:    channel default
Needs:    pnpm build · pnpm start + curl · python3
```

The last unwritten Wave 1 article. Three experiments, and **experiment A produces an artifact I have not seen published accurately anywhere**: the actual nesting order of every file convention, measured from rendered output rather than from a docs diagram.

---

## 1. `app/conventions/` — every convention in one route

One segment carrying all of them, each rendering an identifiable marker so the nesting is readable from the HTML.

**`demos/next-lab/app/conventions/layout.tsx`**

```tsx
export default function ConventionsLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div data-marker="layout">
      <p>layout</p>
      {children}
    </div>
  )
}
```

**`demos/next-lab/app/conventions/template.tsx`**

```tsx
export default function ConventionsTemplate({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div data-marker="template">
      <p>template</p>
      {children}
    </div>
  )
}
```

**`demos/next-lab/app/conventions/loading.tsx`**

```tsx
export default function ConventionsLoading() {
  return <p data-marker="loading">loading</p>
}
```

**`demos/next-lab/app/conventions/error.tsx`**

```tsx
'use client'

// error.tsx must be a Client Component — it needs an error boundary, which
// only exists on the client. Experiment B confirms whether the framework
// enforces this or merely documents it.
export default function ConventionsError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div data-marker="error">
      <p>error: {error.message}</p>
      <button onClick={reset}>reset</button>
    </div>
  )
}
```

**`demos/next-lab/app/conventions/not-found.tsx`**

```tsx
export default function ConventionsNotFound() {
  return <p data-marker="not-found">not-found</p>
}
```

**`demos/next-lab/app/conventions/page.tsx`**

```tsx
import { connection } from 'next/server'

export default async function ConventionsPage() {
  // Forces a request-time render so the loading boundary is exercised.
  await connection()
  return <p data-marker="page">page</p>
}
```

**`demos/next-lab/app/conventions/_private/note.md`** — a private folder, to prove colocation:

```md
Files in an underscore-prefixed folder are never routed. This exists to be
counted in the build table (or rather, not counted).
```

Also add **`demos/next-lab/app/conventions/nested/page.tsx`** — a child segment with no conventions of its own, so the article can show inheritance:

```tsx
export default function NestedPage() {
  return <p data-marker="nested-page">nested page</p>
}
```

## 2. EXPERIMENT A — the real nesting order

```bash
pnpm build && pnpm start
curl -s http://localhost:PORT/conventions
curl -s http://localhost:PORT/conventions/nested
```

Capture into `observations/convention-nesting.txt`:

1. The `data-marker` elements in **document order** for `/conventions`, with nesting depth. Strip everything else.
2. The same for `/conventions/nested` — which wrappers were inherited, and did `template.tsx` apply?
3. `.next/server/app/conventions.html` — **which markers are in the shell?** I expect `layout`, `template`, and `loading`; I expect `page` absent because `connection()` defers it. Confirm or correct.
4. The build table rows for both routes, plus confirmation that `_private/` produced no route.

**Do not reproduce a nesting order from the documentation.** Report the order the markers actually appear in. If it differs from the commonly-published diagram, that difference is the finding.

## 3. EXPERIMENT B — is `'use client'` on `error.tsx` enforced or merely conventional?

Remove `'use client'` from `error.tsx` and rebuild.

→ `observations/error-boundary-client.txt` — the exact error, or a note that it builds fine.

Then restore. If it builds without the directive, the article says so plainly rather than repeating the received wisdom.

## 4. EXPERIMENT C — does `error.tsx` catch a prerender-time throw?

**The one connected to session 7's phase-dependence finding, and the one I can't predict.**

Two scratch variants of a page under `/conventions`:

**C1 — throw in a Server Component on a route that would prerender.** No `connection()`, no dynamic API, just `throw new Error('boom')` in the page body.

- Does `next build` **fail**, or does it **succeed** with `error.tsx`'s output baked into the prerendered HTML?
- If it succeeds, read `.next/server/app/...html` and record what's in there.

**C2 — the same throw, but with an outer `connection()` above a `<Suspense>` so the subtree is postponed.**

- Does the build now pass and the error surface only at request time?
- Capture `curl -i` — status code, and whether the error UI or a digest comes through.

→ `observations/error-boundary-phase.txt`

This tests whether error boundaries are subject to the same *enforcement follows execution* rule as everything else in the matrix. If C1 bakes an error page into a static artifact, that is a genuinely surprising and important behaviour — a route that ships its own failure as cached HTML.

## 5. Antipattern (extract-only, tsconfig-excluded)

**`antipatterns/error-boundary-cannot-catch.tsx`**

```tsx
// antipattern: error.tsx cannot catch errors thrown by the layout in its own
// segment — the boundary sits inside that layout, so a layout throw escapes
// upward. Only a parent segment's error.tsx, or global-error.tsx, catches it.
// fails: at runtime, in the parent boundary — not where you put the file.
export default function BadLayout() {
  throw new Error('layouts throw past their own sibling error.tsx')
}
```

**Verify that comment before extracting it.** It's my claim, not a measurement. Add a scratch test if cheap; if the measurement contradicts the comment, fix the comment and tell me.

## 6. Template

`prompts/session10/file-conventions-and-the-route-tree.md.tpl` ships with this. Placeholders:

- `{NESTING_ORDER}` — experiment A
- `{ERROR_CLIENT_RESULT}` — experiment B
- `{ERROR_PHASE_RESULT}` — experiment C

Move to `docs/concepts/foundations/` as the final step. Ships `draft`.

---

## Acceptance

- [ ] All convention files created; `/conventions` and `/conventions/nested` build and are reachable
- [ ] `_private/` confirmed to produce no route
- [ ] Experiment A: nesting order captured from **rendered output**, not documentation; shell membership recorded
- [ ] Experiment B answered
- [ ] Experiment C: both variants run; if C1 bakes an error page into the shell, say so prominently
- [ ] The antipattern's claim verified before extraction, or corrected
- [ ] Placeholders filled from `observations/`; gates green
