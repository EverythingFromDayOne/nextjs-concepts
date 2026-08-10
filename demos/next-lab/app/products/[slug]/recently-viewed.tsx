import { cookies } from 'next/headers'
import { getProductsByIds } from '@/lib/catalog'

export async function RecentlyViewed() {
  // The identity read happens HERE, outside any cached scope. The ids are
  // then passed to getProductsByIds as an argument, so the lookup can be
  // cached without the cache knowing who asked.
  const raw = (await cookies()).get('recently-viewed')?.value
  const ids = raw ? (JSON.parse(raw) as string[]) : []
  if (ids.length === 0) return null

  const products = await getProductsByIds(ids)
  return (
    <section>
      <h2>Recently viewed</h2>
      <ul>{products.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
    </section>
  )
}
