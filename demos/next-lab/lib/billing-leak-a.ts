import { cacheLife } from 'next/cache'
import { cookies } from 'next/headers'
import { db } from './db'

export async function getDashboardLeakA() {
  'use cache'
  cacheLife('minutes')
  const uid = (await cookies()).get('uid')?.value ?? 'anonymous'
  return db.usage.forUser(uid)
}
