import { cacheLife } from 'next/cache'
import { db } from './db'

/**
 * Legal — and a trap. The cache entry has an honest creation time, so
 * new Date() builds and runs here. The value freezes at entry creation and
 * is wrong for every later reader who treats it as "now."
 */
export async function getStamped() {
  'use cache'
  cacheLife('minutes')
  return { at: new Date().toISOString(), data: await db.report.summary() }
}
