// antipattern: a directive-less component that reads a server-only API,
// reached through a Client Component's import graph. The import itself
// doesn't error — it silently reclassifies this module as client code — but
// next/headers has no client-side implementation, so the build fails the
// moment the reclassified module tries to use it.
// fails: build
import { cookies } from 'next/headers'

export async function AccountBadge() {
  const store = await cookies()
  return <span>{store.get('plan')?.value ?? 'free'}</span>
}
