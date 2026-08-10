// antipattern: four values that cannot suspend. Each would be computed once
// during the prerender and served to every visitor for the life of the
// deployment. Extract-only; never compiled.
export function Variants() {
  const a = new Date() // build-time clock, frozen
  const b = Date.now() // same, as a number
  const c = Math.random() // one "random" value for everyone
  const d = crypto.randomUUID() // one "unique" id for everyone
  return <pre>{String([a, b, c, d])}</pre>
}
