# Cursor — session 9: article 7 (`rendering/client-side-rendering`)

```
Channel:  #nextjs-concepts
Invoke:   @Cursor follow prompts/session9-article7-demos.md
Model:    channel default
Needs:    pnpm build · pnpm start + curl · python3
```

The fourth answer. Articles 1 and 6 both assert every piece of data gets one of four — cache, stream, block, push to the client — and only three have owning articles.

Three experiments. **Experiment B tests a claim I'm not confident in, and experiment C is optional because it adds a dependency.**

---

## 1. `app/sketchpad/` — where client-side is actually correct

Not a strawman. A drawing surface is client-side because the *interaction rate* makes any server round trip absurd, not because someone was lazy.

**`demos/next-lab/app/sketchpad/sketchpad.tsx`**

```tsx
'use client'

// client: pointer events at ~60Hz and a mutable canvas ref. Neither has a
// server representation, and neither would survive a round trip.
import { useEffect, useRef, useState } from 'react'

export function Sketchpad() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [drawing, setDrawing] = useState(false)
  const [strokes, setStrokes] = useState(0)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    // Device pixel ratio is a browser fact. There is no server answer.
    const dpr = window.devicePixelRatio ?? 1
    canvas.width = canvas.clientWidth * dpr
    canvas.height = canvas.clientHeight * dpr
    canvas.getContext('2d')?.scale(dpr, dpr)
  }, [])

  function draw(e: React.PointerEvent<HTMLCanvasElement>) {
    if (!drawing) return
    const ctx = canvasRef.current?.getContext('2d')
    if (!ctx) return
    const rect = canvasRef.current!.getBoundingClientRect()
    ctx.lineTo(e.clientX - rect.left, e.clientY - rect.top)
    ctx.stroke()
  }

  return (
    <div>
      <canvas
        ref={canvasRef}
        style={{ width: '100%', height: 300, border: '1px solid #ccc' }}
        onPointerDown={(e) => {
          setDrawing(true)
          setStrokes((s) => s + 1)
          const ctx = canvasRef.current?.getContext('2d')
          const rect = canvasRef.current!.getBoundingClientRect()
          ctx?.beginPath()
          ctx?.moveTo(e.clientX - rect.left, e.clientY - rect.top)
        }}
        onPointerMove={draw}
        onPointerUp={() => setDrawing(false)}
      />
      <p>{strokes} strokes</p>
    </div>
  )
}
```

**`demos/next-lab/app/sketchpad/page.tsx`**

```tsx
import { Sketchpad } from './sketchpad'

/**
 * The page itself is a Server Component. The prose around the canvas is
 * prerendered and indexable; only the canvas is client-side. "Push it to
 * the client" is a per-boundary answer, not a per-page one.
 */
export default function SketchpadPage() {
  return (
    <main>
      <h1>Sketchpad</h1>
      <p>Draw with a pointer. Strokes are counted locally.</p>
      <Sketchpad />
    </main>
  )
}
```

## 2. `app/client-only/` — `next/dynamic` with `ssr: false`

**`demos/next-lab/app/client-only/heavy-widget.tsx`**

```tsx
'use client'

// client: reads window during the first render, so it cannot be
// server-rendered at all — not merely "shouldn't be".
export function HeavyWidget() {
  const w = window.innerWidth
  return <p>Viewport is {w}px wide.</p>
}
```

**`demos/next-lab/app/client-only/loader.tsx`**

```tsx
'use client'

import dynamic from 'next/dynamic'

// ssr: false skips server rendering entirely. The fallback is what lands
// in the HTML; the real component only exists after hydration.
export const HeavyWidgetClientOnly = dynamic(
  () => import('./heavy-widget').then((m) => m.HeavyWidget),
  { ssr: false, loading: () => <p>Loading widget…</p> }
)
```

**`demos/next-lab/app/client-only/page.tsx`**

```tsx
import { HeavyWidgetClientOnly } from './loader'

export default function ClientOnlyPage() {
  return (
    <main>
      <h1>Client-only rendering</h1>
      <p>This paragraph is prerendered and will appear in the HTML.</p>
      <HeavyWidgetClientOnly />
    </main>
  )
}
```

## 3. EXPERIMENT A — what a client-rendered page actually puts in the HTML

The SEO question, answered by measurement rather than folklore.

```bash
pnpm build
```

Capture into `observations/client-only-shell.txt`:

1. `.next/server/app/client-only.html` — trimmed to `<main>`…`</main>`. Is the `loading` fallback there? Is "Viewport is …px wide" there?
2. `.next/server/app/sketchpad.html` — same. Is the `<h1>` and prose present? Is the canvas?
3. Both routes' build-table rows.
4. For contrast, the `<main>` from `.next/server/app/catalog.html`.

**State the limit explicitly in the capture's provenance line:** this measures *what is in the HTML*, not what any search engine does with it. We cannot measure crawler behaviour, and the article must not imply we did.

## 4. EXPERIMENT B — is `ssr: false` legal in a Server Component?

**I believe `next/dynamic` with `ssr: false` is rejected inside a Server Component and must live in a `'use client'` file — which is why §2 puts it in `loader.tsx`. I am not confident.** Verify.

Scratch route: call `dynamic(() => import(...), { ssr: false })` **directly in a Server Component page**, no `'use client'` file in between. Build.

→ `observations/ssr-false-in-server-component.txt` — the exact error, or a note that it builds fine.

If it builds, my §2 indirection is unnecessary ceremony and the article should say so. If it errors, capture the message — it's the kind of error people hit and search for.

## 5. EXPERIMENT C — optional, adds a dependency

**Only if you judge the dependency acceptable; skip and say so otherwise.** The question: when a Client Component fetches data that a Server Component could have fetched, does the data cross the wire twice?

Add TanStack Query v5 to `demos/next-lab`, one route:

- Server Component fetches products and passes them to a Client Component
- That Client Component *also* runs `useQuery` against a route handler for the same data

Measure: response bytes, and whether the network panel shows a client fetch for data already in the payload.

→ `observations/query-double-fetch.txt`

**This is an invented dependency and I'm flagging it as one.** `reactjs-concepts` owns TanStack Query; this repo may not want it. If you skip, the article cross-links instead and loses a measurement. Your call — record which you chose and why.

## 6. Antipattern (extract-only, tsconfig-excluded)

**`antipatterns/client-page-for-static-content.tsx`**

```tsx
// antipattern: 'use client' at the page root for content that never changes
// and has no interaction. The whole subtree joins the client bundle, the
// prose leaves the prerendered HTML, and nothing is gained.
// fails: silently — it works, which is the problem.
'use client'

export default function AboutPage() {
  return (
    <main>
      <h1>About us</h1>
      <p>Founded in 2019. We make things.</p>
    </main>
  )
}
```

## 7. Template

`prompts/session9/client-side-rendering.md.tpl` ships with this. Placeholders the builder will refuse to fill:

- `{SHELL_COMPARISON}` — experiment A
- `{SSR_FALSE_IN_SERVER}` — experiment B
- `{QUERY_RESULT}` — experiment C, **or an explicit note that it was skipped and why**

Move to `docs/concepts/rendering/` as the final step. Ships `draft`.

---

## Acceptance

- [ ] Both routes build and are reachable; antipattern excluded from tsconfig
- [ ] Experiment A captured, with the crawler-behaviour limit stated in the provenance line
- [ ] Experiment B answered — my §2 assumption confirmed or corrected
- [ ] Experiment C run or skipped, with the reason recorded
- [ ] All three placeholders filled from `observations/`, not from prose
- [ ] Gates green
