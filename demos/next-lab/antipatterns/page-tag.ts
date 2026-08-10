// antipattern: tagging the page instead of the entity. cacheTag('dashboard')
// invalidates everything or nothing. Extract-only; never compiled.
import { cacheLife, cacheTag } from 'next/cache'
import { db } from '../lib/db'

export async function getDashboardBundle() {
  'use cache'
  cacheLife('minutes')
  cacheTag('dashboard')
  return {
    plans: await db.plans.findMany(),
    alerts: await db.alerts.findMany(),
  }
}
