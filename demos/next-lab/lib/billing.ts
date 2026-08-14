import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

export async function getPlans() {
  'use cache'
  cacheLife('days')
  cacheTag('plans')
  return db.mutablePlans.findMany()
}

// uid is an ARGUMENT. It is therefore in the compiler-derived key, which
// is the entire difference between a per-user entry and a shared one.
export async function getUsage(uid: string) {
  'use cache'
  cacheLife('minutes')
  cacheTag(`usage:${uid}`)
  return db.usage.forUser(uid)
}
