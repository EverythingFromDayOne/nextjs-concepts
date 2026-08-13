// antipattern: a 'use cache' function that isn't async. The directive requires
// it — there is no synchronous cache entry, because a cache read is always at
// least one await away.
// fails: build
export function getNonAsync() {
  'use cache'
  return 42
}
