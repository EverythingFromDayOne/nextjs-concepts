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
