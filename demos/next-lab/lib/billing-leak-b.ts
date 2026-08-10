import { cacheLife } from 'next/cache'
import { db } from './db'

let lastSeenUid = 'anonymous' // set by an uncached caller before the call

export function rememberUid(uid: string) {
  lastSeenUid = uid
}

export async function getDashboardLeakB() {
  'use cache'
  cacheLife('minutes')
  return db.usage.forUser(lastSeenUid)
}
