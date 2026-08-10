import { cacheLife } from 'next/cache'
import { db } from './db'

/**
 * No cacheTag, deliberately: nothing in our system can invalidate a third
 * party's status feed, so a tag would be decoration. Time is the only
 * honest lever.
 *
 * cacheLife('minutes') keeps this in the prerender. 'seconds' would not —
 * its one-minute expire falls under the exclusion threshold.
 */
export async function getAlerts() {
  'use cache'
  cacheLife('minutes')
  return db.alerts.findMany()
}
