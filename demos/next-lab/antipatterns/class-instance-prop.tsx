// antipattern: a class instance passed as a prop from a Server Component to a
// Client Component. Measured (article 8's enforcement matrix, probe 10): this
// is a build-time prerender error, not a silent shape with missing methods.
// fails: build
export class Widget {
  constructor(public name: string) {}
  getName() {
    return this.name
  }
}
