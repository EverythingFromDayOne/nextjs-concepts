import { Suspense } from 'react'
import { cacheLife, cacheTag } from 'next/cache'
import { cookies } from 'next/headers'
import { db } from '@/lib/db'

export default function BasicPage() {
  return (
    <main>
      <Announcements />
      <Suspense fallback={<p aria-busy="true">Loading stats…</p>}>
        <PersonalStats />
      </Suspense>
    </main>
  )
}

async function Announcements() {
  'use cache'
  cacheLife('hours')
  cacheTag('announcements')
  const items = await db.announcements.findMany()
  return (
    <ul>
      {items.map((a) => (
        <li key={a.id}>{a.title}</li>
      ))}
    </ul>
  )
}

async function PersonalStats() {
  const uid = (await cookies()).get('uid')?.value
  if (!uid) return null
  const stats = await getStats(uid)
  return (
    <p data-uid={uid}>
      {stats.requests.toLocaleString('en-US')} requests · {stats.storageMb} MB
    </p>
  )
}

async function getStats(uid: string) {
  'use cache'
  cacheLife('minutes')
  cacheTag(`stats:${uid}`)
  return db.usage.forUser(uid)
}
