import { db } from './db'

/**
 * No 'use cache', deliberately. Inventory that is thirty seconds stale
 * sells things we do not have. This is the "stream it" answer.
 */
export async function getLiveStock(slug: string) {
  return db.inventory.forSlug(slug)
}
