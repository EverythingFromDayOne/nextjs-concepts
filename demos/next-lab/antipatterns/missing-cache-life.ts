// antipattern: a cached scope with no cacheLife. The default profile applies,
// and an inner short-lived cache can drag this scope down — or produce a
// prerender error when the outer scope has no explicit lifetime. Extract-only.
import { cacheTag } from 'next/cache'
import { db } from '../lib/db'

export async function getPlansMissingLife() {
  'use cache'
  // no cacheLife(...)
  cacheTag('plans')
  return db.plans.findMany()
}
