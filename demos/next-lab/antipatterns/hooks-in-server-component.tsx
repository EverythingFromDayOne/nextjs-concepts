// antipattern: a hook called in a Server Component with no 'use client'. There
// is no client instance for useState to attach to — this isn't a lint rule
// being strict, it is a real absence.
// fails: build
import { useState } from 'react'

export function Counter() {
  const [count] = useState(0)
  return <p>{count}</p>
}
