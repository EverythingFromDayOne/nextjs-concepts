---
article_id: file-conventions-and-the-route-tree
description: The file conventions are a fixed wrapper stack, and each wrapper has a different relationship to the two rendering passes
concept_folder: foundations
wave: 1
related:
  - foundations/thinking-in-the-app-router
  - rendering/static-shell-and-streaming
  - routing/layouts-templates-and-state
  - routing/error-handling-and-recovery
next_baseline: "16.3"
verified_against: next@16.3.0
verified_on: 2026-08-14
status: draft
---

# File conventions and the route tree

> **Lead with this.** The file conventions are not special filenames. They are a **declarative wrapper stack** — each file becomes a component wrapped around the one below it, in a fixed order you don't control.
>
> What makes this worth an article rather than a reference table is that each wrapper has a **different relationship to the two rendering passes**. One of them is a Suspense boundary, so it lands in the shell. One is an error boundary, so it must be a Client Component. One remounts where its neighbour persists. Knowing the order tells you what nests inside what; knowing the relationships tells you what actually happens.

---

## What it is

Two files create URLs. Everything else wraps them.

| File | Creates a route? | What it is |
| --- | --- | --- |
| `page.tsx` | **Yes** | The UI for this URL |
| `route.ts` | **Yes** | An HTTP endpoint for this URL |
| `layout.tsx` | No | A wrapper that persists across navigation within its segment |
| `template.tsx` | No | A wrapper that remounts on every navigation |
| `loading.tsx` | No | A `<Suspense>` boundary; this file is its fallback |
| `error.tsx` | No | An error boundary for this segment's children |
| `not-found.tsx` | No | UI for `notFound()` within this segment |
| `default.tsx` | No | Fallback UI for an unmatched parallel-route slot |
| `global-error.tsx` | No | The root error boundary; replaces the whole `<html>` |

Everything else in `app/` — components, tests, styles, utilities — is just files. **Colocation is safe: only `page` and `route` produce URLs.** An underscore-prefixed folder (`_components`) is excluded from routing entirely, which matters when a filename might otherwise collide.

The route tree and the component tree are not the same shape. Folders create URL segments; conventions create wrappers. A folder with no `page.tsx` contributes a path segment and no UI.

---

## How it works under the hood

### The measured nesting order

The bundled `next@16.3.0` docs already publish this order as text, not just a diagram (`app/getting-started/project-structure`, "Component hierarchy"): `layout` → `template` → `error` (boundary) → `loading` (Suspense) → `not-found` (boundary) → `page` or a nested `layout`, each nested inside the one before it. Rendering `/conventions` **confirms that order rather than contradicting it** — the thing worth measuring wasn't the order, it's which of those six names put an actual node on the page and which sit invisibly until something fires:

| Position (outside → inside) | File | Puts a node on the page unconditionally? | In the `/conventions` build shell? |
| --- | --- | --- | --- |
| 0 | `layout.tsx` | Yes — its own wrapper element | Yes |
| 1 | `template.tsx` | Yes — its own wrapper element | Yes |
| 2 | `error.tsx` | No — a boundary with no output until something throws | Present as a boundary; contributes nothing visible |
| 3 | `loading.tsx` | Only while its Suspense boundary is pending | Yes — the shell freezes mid-fallback here |
| 3 | `not-found.tsx` | Only if `notFound()` fires | Didn't fire — absent |
| 3 | `page.tsx` | Once its Suspense boundary resolves | No — deferred past the shell by `connection()` |

`error`, `not-found`, and `page` share depth 3 because they're **alternate outcomes of the same slot**, not three stacked layers — only one of them is ever actually present at once. That's what a name-only list can't show: it reads like six wrappers, but only two of the six (`layout`, `template`) are unconditional.

Measured document order for `/conventions` (`curl` against `next build && next start`): `layout` → `template` → `loading` → `page`. The `page` marker arrives later in the same streamed response, as an out-of-band chunk that swaps into the position `loading` held — it is not literally nested inside `loading` in the final DOM.

`/conventions/nested` has no conventions of its own. It inherits `layout` and `template` — both markers render — and it inherits the Suspense boundary from the parent's `loading.tsx` too, though the boundary never shows a fallback: `nested/page.tsx` has no dynamic API, so the boundary resolves before anything would paint. Document order: `layout` → `template` → `nested-page`.

```
├ ◐ /conventions
├ ○ /conventions/nested
```

`/conventions` ships Partial Prerender — `connection()` in `page.tsx` is the only thing making it dynamic; the other conventions don't. `/conventions/nested` ships fully static, confirming that inheriting a parent's `loading.tsx` boundary doesn't by itself cost a route its static shell. `app/conventions/_private/note.md` produced no route at all: it never appears in the build table, skipped rather than listed and excluded.

Read the shell membership row carefully — it's the part a nesting list can't tell you. The wrappers above the Suspense boundary are prerendered; the page below it is not, because it defers. That's the same mechanism as everywhere else in this model: `loading.tsx` is a `<Suspense>` boundary, and its fallback goes into the shell exactly as any other fallback does.

Which is why `loading.tsx` isn't a separate feature. It is **one Suspense boundary at one fixed position** — the segment root — with your file as its fallback. Convenient when the whole segment is one hole; too blunt when it isn't. Since 16.3 extracts shells from arbitrary trees, explicit boundaries are usually the better tool, and `loading.tsx` stopped being the only way to get a prefetchable shell.

### `error.tsx` is a Client Component, and the reason is structural

An error boundary needs `componentDidCatch`, which needs a component instance, which needs the client. A Server Component finished executing on another machine — there is nothing left to catch anything.

<!-- extract: demos/next-lab/app/conventions/error.tsx -->
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

Removing the directive and rebuilding fails immediately, naming the file and the fix directly:

```
Error: demos/next-lab/app/conventions/error.tsx must be a Client Component. Add the "use client" directive the top of the file to resolve this issue.
```

This isn't the generic "you used a client-only API in a Server Component" diagnostic that a hooks or event-handler misuse triggers elsewhere in this model — nothing about `error.tsx`'s function body would otherwise mark it client-only. The compiler recognizes the file by its convention name and dedicates a specific check to it, rather than waiting to see whether the directive-less module happens to use something the server can't provide. **Enforced, not merely conventional.**

The consequence people trip on: **`error.tsx` cannot catch errors thrown by the layout in its own segment.** The boundary is rendered *inside* that layout, so a layout throw escapes past it. Only a parent segment's `error.tsx` — or `global-error.tsx` — is positioned to catch it.

<!-- extract: demos/next-lab/antipatterns/error-boundary-cannot-catch.tsx -->
```tsx
// antipattern: error.tsx cannot catch errors thrown by the layout in its own
// segment — the boundary sits inside that layout, so a layout throw escapes
// upward. Only a parent segment's error.tsx, or global-error.tsx, catches it.
// fails: at runtime, in the parent boundary — not where you put the file.
export default function BadLayout() {
  throw new Error('layouts throw past their own sibling error.tsx')
}
```

### When the error boundary fires, and what gets stored

This is where the conventions meet the enforcement rule from [`rules-of-the-server-boundary`](./rules-of-the-server-boundary.md): **enforcement follows execution.** A Server Component that throws is only caught when it runs — and whether it runs at build depends on whether its subtree is prerendered.

A synchronous, undeferred throw — no `connection()`, nothing wrapping it in `<Suspense>` — fails the build outright, with a plain stack trace pointing at the throwing line. `error.tsx` never enters the picture: nothing in the build's output mentions a boundary or a fallback UI. **This falsifies the tempting hypothesis that a route could ship its own failure as cached HTML** — it can't, at least not this way. The reason is the same rule this article has already measured for `loading.tsx`: a generic exception during the synchronous static-generation pass isn't something Cache Components' renderer knows how to defer, the way it defers `connection()`/`cookies()` — those raise a specific postponement signal the renderer recognizes and pauses on. Error boundaries are a *client*-side mechanism (see "structural" above): they catch errors during a request-time render or hydration pass, not errors that abort the server's one-shot attempt to produce a static shell.

Defer the identical throw behind `connection()` inside an explicit `<Suspense>`, and the build passes — the route ships Partial Prerender, same as any other route with a properly-guarded dynamic read. The failure now surfaces only at request time: the response is `200 OK` with `x-nextjs-postponed: 1`, and the thrown error travels inside the streamed RSC payload as a digest, never as a non-200 status or a plaintext message. Once the client hydrates, that digest triggers the nearest `error.tsx` above the boundary, which replaces the pending fallback with its own UI in the browser — never in anything the server persisted.

So the precise version of this finding isn't "`error.tsx` catches a build-time throw" — it's that `error.tsx` has nothing to do at build time, in either direction. Whether a throw fails the build or waits for a real request is decided entirely by whether the code reaching it is deferred behind a dynamic API inside a `<Suspense>` boundary, exactly the same rule that already governs every other check in this model. The same deferral test on a **layout's own throw** (rather than a page's) confirms the antipattern below by the same mechanism: a layout authors its JSX around `{children}`, which is exactly the part of the tree its own `error.tsx` is wired to protect — so the layout's own throw never reaches that boundary, deferred or not.

**Stated plainly, since it's easy to read the above as a nuance rather than a rule: `error.tsx` is a request-time recovery mechanism, full stop. It never rescues a failing build.** A build that fails, fails — with or without an `error.tsx` anywhere above the throw. The only thing an error boundary can ever do is replace a *pending* fallback with its own UI after a request resumes a deferred render; it cannot reach back and turn a build failure into a shipped artifact, because by the time the build has failed there is no render left for it to attach to.

### `layout` persists, `template` remounts

Both wrap `children`. The difference is what happens on navigation within the segment.

<!-- extract: demos/next-lab/app/conventions/layout.tsx -->
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

<!-- extract: demos/next-lab/app/conventions/template.tsx -->
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

A layout keeps its instance across sibling navigations — state survives, effects don't re-run, scroll position persists. A template gets a fresh instance every time, so effects re-fire and state resets. Reach for `template.tsx` when a per-navigation reset is the *point*: entry animations, per-page analytics that must fire on every view, resetting a form between records.

This distinction got sharper in 16. With React `<Activity>` keeping previous routes alive in `hidden` mode, unmounting no longer happens by accident on navigation — so a `template.tsx` is now one of the few places a deliberate remount still happens.

### Inheritance down the tree

A child segment with no conventions of its own inherits every wrapper above it. Add a `layout.tsx` in the child and it nests *inside* the parent's, not instead of it.

<!-- extract: demos/next-lab/app/conventions/nested/page.tsx -->
```tsx
export default function NestedPage() {
  return <p data-marker="nested-page">nested page</p>
}
```

That inheritance is why a single runtime read in a root layout de-opts every route beneath it, and why a `loading.tsx` high in the tree produces a coarse shell for everything below. **Conventions placed high have app-wide blast radius in both directions** — that's the highest-leverage placement decision in the file system.

### Colocation and private folders

Only `page` and `route` create URLs, so components, tests, and styles can live next to what uses them.

Two cases where being deliberate pays:

- **`_private/` folders** are excluded from routing entirely. Useful when a shared folder might otherwise be mistaken for a segment.
- **`(group)` folders** create no URL segment but *do* create a layout boundary — the mechanism behind multiple root layouts. That belongs to [`route-groups-and-project-structure`](../routing/route-groups-and-project-structure.md).

---

## Basic usage

The minimum viable segment is one file:

<!-- extract: demos/next-lab/app/conventions/page.tsx -->
```tsx
import { connection } from 'next/server'

export default async function ConventionsPage() {
  // Forces a request-time render so the loading boundary is exercised.
  await connection()
  return <p data-marker="page">page</p>
}
```

Add wrappers only where you need them. Each one you add applies to everything beneath.

---

## Walkthrough — building a segment one convention at a time

Add each convention in turn and read what changes in the build output and the shell. That reading is the exercise; the code is trivial.

### Step 1 — `page.tsx` alone

One route, no wrappers. Read the build table: static or partial-prerender, depending on whether the page defers.

### Step 2 — add `layout.tsx`

The marker appears around the page in the rendered output. Navigate between sibling routes under this layout and confirm its state persists.

### Step 3 — add `loading.tsx`

Now the build output changes shape. Read `.next/server/app/conventions.html` — the fallback is in the shell, the page is not. **This is the step where a file convention visibly changes the prerender**, and it's the one to slow down on.

### Step 4 — add `template.tsx`

Navigate between siblings again. The template's effects re-fire where the layout's did not. Both wrappers are present in the rendered output; only one keeps its instance.

### Step 5 — add `error.tsx`, then break something

Throw from the page. The boundary catches it. Then throw from the *layout* and watch the error escape to the parent — the boundary lives inside the thing that threw.

### Step 6 — verify the loop

```bash
pnpm build && pnpm start
```

1. `curl` the route and list markers in document order. Compare against the measured table above.
2. Read `.next/server/app/conventions.html` — which markers are in the shell.
3. Load `/conventions/nested` and confirm which wrappers were inherited.
4. Confirm `_private/` produced no route in the build table.

---

## Then vs now

Cite: [`docs/evolution-ledger.md`](../../evolution-ledger.md) rows 8, 20.

| Aspect | Next 13–15 | Next 16+ | What changed underneath |
| --- | --- | --- | --- |
| `loading.tsx` | The only prefetchable loading state a route could have; forgetting it meant a blocking navigation with no warning | One Suspense boundary at a fixed position; shells are extracted from any tree | The prefetch payload went from **a file you remembered to write** to **an artifact derived from your boundary placement**, which removed a silent cliff and demoted `loading.tsx` from mechanism to convenience. |
| What a layout costs | A wrapper that re-rendered per request along with the route | A wrapper whose runtime reads abort the prerender for **every route beneath it** | With per-boundary prerendering, a layout's blast radius became structural rather than incidental — one `cookies()` high in the tree removes the shell from an entire subtree. |
| `template.tsx` | The way to force a remount, alongside routes unmounting naturally | Often the *only* remount, since `<Activity>` keeps previous routes alive | Unmounting stopped happening by default on navigation, so deliberate remounts need a deliberate mechanism. |
| When `error.tsx` fires for a server throw | At request time, because rendering happened at request time | At build **or** request time, depending on whether the subtree is prerendered | Error boundaries inherited the general rule that enforcement follows execution — see the measured result above. |
| `middleware.ts` | A root-level convention | Renamed to `proxy.ts` | Renamed to clarify that it sits at the network boundary, outside the rendering model entirely. |

---

## Real-world patterns

**Put conventions as low as they'll go.** Same rule as boundaries and client directives. A `loading.tsx` at the root gives every route the same coarse shell.

**Prefer explicit `<Suspense>` to `loading.tsx`** when a segment has more than one independent wait. One boundary at the segment root couples them.

**Don't reach for `template.tsx` to fix a state bug.** If state is persisting when you didn't expect it, the cause is usually `<Activity>` and the fix is an explicit reset or deriving from the URL. A template remounts *everything* beneath it.

**Give every `error.tsx` a working `reset`.** A boundary with no recovery path is a dead end for the user. And put one at the root — an uncaught throw with no boundary is a blank page.

**Colocate freely.** Only `page` and `route` create URLs. Tests, components, and styles belong next to what uses them, not in a parallel tree.

**Read `.next/server/app/<route>.html` after adding a convention.** It is the only place the effect on the shell is visible; a response body shows a completed stream.

---

## API and type reference

| Convention | Must be | Notes |
| --- | --- | --- |
| `page.tsx` | default export | Creates a URL. Receives `params` and `searchParams` as promises. |
| `route.ts` | named HTTP-verb exports | Creates a URL. Cannot coexist with `page.tsx` in the same segment. |
| `layout.tsx` | default export, accepts `children` | Persists across navigation. Root layout must render `<html>` and `<body>`. |
| `template.tsx` | default export, accepts `children` | Remounts every navigation. |
| `loading.tsx` | default export | A `<Suspense>` fallback at the segment root. |
| `error.tsx` | **`'use client'`**, receives `error` and `reset` | Cannot catch its own segment's layout. |
| `global-error.tsx` | `'use client'`, renders `<html>` and `<body>` | Replaces the root layout when it fires. |
| `not-found.tsx` | default export | Rendered by `notFound()`. |
| `default.tsx` | default export | Fallback for an unmatched parallel-route slot. |

---

## Common mistakes

**1. Expecting `error.tsx` to catch its own layout.** The boundary renders inside that layout. Use the parent's boundary, or `global-error.tsx`.

**2. Forgetting `'use client'` on `error.tsx`.** See the measured result above for exactly what happens.

**3. Treating `loading.tsx` as the loading mechanism.** It's one boundary at one position. Segments with several independent waits want explicit boundaries.

**4. A `loading.tsx` at the root.** Every route inherits the coarsest possible shell.

**5. Runtime reads in a root layout.** One `cookies()` there costs the shell for the entire app. If the value must drive an `<html>` attribute, an inline script that sets it before paint keeps the shell intact.

**6. Reaching for `template.tsx` to reset one piece of state.** It remounts the whole subtree. Reset explicitly or derive from the URL.

**7. Assuming a folder without `page.tsx` is inert.** It still contributes a URL segment, and a `layout.tsx` there still wraps everything beneath.

**8. Fearing colocation.** Only `page` and `route` create URLs. Use `_private/` when you want the exclusion to be unmistakable.

---

## Exercises

**1. Predict the order.** Before reading the measured table, write down the order you expect the wrappers to nest in. Then check. The disagreement is usually about where the error boundary sits relative to the loading boundary.

**2. Move a convention up, then down.** Take a `loading.tsx` on a leaf segment and move it to the parent. Read both routes' prerendered HTML before and after.

*Hint: you're looking for how much of the tree the fallback replaces.*

**3. Break a layout on purpose.** Throw from a `layout.tsx` with a sibling `error.tsx` present. Confirm which boundary catches it, then add one to the parent segment and confirm again.

---

## Summary

- Only `page` and `route` create URLs. Everything else wraps them, and colocation is safe.
- The conventions form a **fixed wrapper stack** — the measured order is above, not a diagram.
- `loading.tsx` is one `<Suspense>` boundary at the segment root, so its fallback lands in the shell like any other.
- `error.tsx` must be a Client Component, and it **cannot catch its own segment's layout**.
- Error boundaries follow the same rule as everything else: enforcement follows execution, so *when* a server throw is caught depends on whether the subtree prerenders.
- **`error.tsx` is request-time recovery only — it never rescues a failing build.** A build-time throw is a hard failure regardless of what boundaries sit above it; only a throw deferred behind a dynamic API inside `<Suspense>` ever reaches an error boundary at all.
- `layout` persists across navigation; `template` remounts. With `<Activity>`, deliberate remounts are now rarer and more significant.
- Conventions placed high inherit downward, which makes root-level placement the highest-leverage decision in the tree.

---

## See also

- [`foundations/thinking-in-the-app-router`](./thinking-in-the-app-router.md) — the two passes these wrappers sit inside
- [`rendering/static-shell-and-streaming`](../rendering/static-shell-and-streaming.md) — why `loading.tsx` is a boundary, not a feature
- [`routing/layouts-templates-and-state`](../routing/layouts-templates-and-state.md) — persistence and remounting in depth
- [`routing/error-handling-and-recovery`](../routing/error-handling-and-recovery.md) — `error.tsx` versus `catchError`, and `retry()`
- [`routing/route-groups-and-project-structure`](../routing/route-groups-and-project-structure.md) — `(groups)`, private folders, multiple root layouts
- [`foundations/rules-of-the-server-boundary`](./rules-of-the-server-boundary.md) — enforcement follows execution

---

## References

- Next.js — File conventions: `page`, `layout`, `template`, `loading`, `error`, `not-found`, `default`, `route`, `global-error`
- Next.js — Getting Started: Layouts and Pages
- Next.js — Guides: Error Handling
- React — `<Suspense>`, `<Activity>`, error boundaries

---

## Demo source

`demos/next-lab/app/conventions/` including `nested/` and `_private/`, `demos/next-lab/antipatterns/error-boundary-cannot-catch.tsx`, and the capture files in `demos/next-lab/observations/`.

> **Verification status.** Verified against `next@16.3.0`. Three items measured this session rather than reproduced from documentation: the **actual wrapper nesting order** and which wrappers land in the prerendered shell (the measurement confirmed the bundled docs' own text description rather than contradicting it — the correction was to which wrappers are DOM-visible versus conditional, not to the order); whether `'use client'` on `error.tsx` is enforced or merely conventional (enforced, with a dedicated build-time check); and whether an error boundary catches a Server Component throw at **build** time when the subtree prerenders (it does not — a plain throw fails the build outright regardless of nearby boundaries, and only surfaces via `error.tsx` when the throw is deferred behind a dynamic API inside `<Suspense>`, at which point it's a request-time-only failure carried as a digest, never baked into a static artifact). The claim that `error.tsx` cannot catch its own segment's layout was authored as an assertion and is verified before extraction — confirmed, not corrected. Every code block is extracted.
