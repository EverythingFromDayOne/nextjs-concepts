'use client'

// client: reads a value that only exists in a browser
import { useEffect, useState } from 'react'

export function ClientTimeSection() {
  const [at, setAt] = useState<string | null>(null)

  // Runs after hydration, never on the server. The null first render is
  // what the server sends and what the client must agree with.
  useEffect(() => {
    setAt(new Date().toISOString())
  }, [])

  return (
    <section>
      <h2>Client time</h2>
      <p>{at ? <>Hydrated at <time>{at}</time></> : 'Not hydrated yet'}</p>
      <p>
        Viewport:{' '}
        {typeof window === 'undefined'
          ? 'unknown on the server'
          : `${window.innerWidth}px`}
      </p>
    </section>
  )
}
