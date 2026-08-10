import { cacheLife, cacheTag } from 'next/cache'
import { db } from './db'

export async function getProduct(slug: string) {
  'use cache'
  cacheLife('hours')
  cacheTag(`product:${slug}`)
  return db.products.findBySlug(slug)
}

/**
 * The cache key is derived from the serialized arguments, so `['p1','p2']`
 * and `['p2','p1']` are two different entries for the same result. Sorting
 * before the call is a cache-hit-rate decision, not a style one.
 */
export async function getProductsByIds(ids: string[]) {
  'use cache'
  cacheLife('hours')
  return db.products.findByIds([...ids].sort())
}

export async function getAllProducts() {
  'use cache'
  cacheLife('hours')
  cacheTag('products')
  return db.products.findMany()
}

export async function getPrerenderedSlugs() {
  return db.products.allSlugs()
}
