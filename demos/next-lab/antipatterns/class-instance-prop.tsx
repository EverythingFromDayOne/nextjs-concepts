// antipattern: a class instance passed as a prop from a Server Component to a
// Client Component. Measured (article 8's enforcement matrix, probe 10): this
// is a hard, named error — never the silent shape with missing methods an
// earlier draft assumed — but *when* it fires is phase-dependent. On a route
// that prerenders this boundary (probe 10a), the build fails. On a route
// where an unrelated dynamic API already deferred that subtree past the
// prerender pass (probe 10b, same shape as app/leak-a), the identical
// violation waits for a real request.
// fails: build (prerendered subtree) — or runtime, if an unrelated dynamic API already deferred the subtree
export class Widget {
  constructor(public name: string) {}
  getName() {
    return this.name
  }
}
