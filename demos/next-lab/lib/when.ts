import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

/**
 * Resolves during the prerender. Note what it cannot return: anything
 * derived from the moment it ran. A cached scope has no honest way to
 * report its own build time to a reader.
 */
export async function getStaticFacts() {
  'use cache'
  cacheLife('hours')
  cacheTag('facts')
  return db.report.summary()
}
