import { cacheLife } from 'next/cache'
import { cookies } from 'next/headers'
import { db } from './db'

// EXPERIMENTAL: 'use cache: private' — browser-memory only, no server-side
// storage. See docs/recipes/caching/user-a-sees-user-b-data.md, "the
// 'use cache: private' alternative" section, before reaching for this.
export async function getDashboardPrivate() {
  'use cache: private'
  cacheLife('minutes')
  const uid = (await cookies()).get('uid')?.value ?? 'anonymous'
  return db.usage.forUser(uid)
}
