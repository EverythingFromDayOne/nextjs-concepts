'use client'

// client: reads window during the first render, so it cannot be
// server-rendered at all — not merely "shouldn't be".
export function HeavyWidget() {
  const w = window.innerWidth
  return <p>Viewport is {w}px wide.</p>
}
