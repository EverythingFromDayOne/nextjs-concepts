import { cacheLife } from 'next/cache'
import { db } from './db'

// The argument is in the key — but every signed-in user passes the same one.
export async function getDashboardLeakC(scope: 'signed-in' | 'anonymous') {
  'use cache'
  cacheLife('minutes')
  const uid = scope === 'signed-in' ? 'user-alice' : 'anonymous'
  return db.usage.forUser(uid)
}
