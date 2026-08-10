import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

export async function getSummary() {
  'use cache'
  cacheLife('hours')
  cacheTag('report:summary')
  return db.report.summary()
}

// No 'use cache' on the three below. Uncached I/O aborts the prerender,
// which is what makes each of them a hole rather than shell.
export async function getRevenue() {
  return db.report.revenue()
}

export async function getTraffic() {
  return db.report.traffic()
}

export async function getErrors() {
  return db.report.errors()
}
