// antipattern: 'use cache' on the page produces one coarse entry and
// forbids every runtime read below it. Extract-only; never compiled.
'use cache'

export default async function Page() {
  return <main>everything below is now one cache entry</main>
}
