// antipattern: instant = false permits a segment to BLOCK. It says nothing
// about whether a value can be computed ahead of a request. A latency
// opt-out cannot resolve a correctness failure. Extract-only.
export const instant = false

export default function Page() {
  return <time>{new Date().toISOString()}</time>
}
