import { Suspense } from 'react'
import { getAllProducts } from '@/lib/catalog'
import { FilterableList } from './filterable-list'

export default function CatalogPage() {
  // Not awaited. The promise crosses the client boundary and is unwrapped
  // with use() on the other side, so the page never blocks.
  const productsPromise = getAllProducts()

  return (
    <Suspense fallback={<p aria-busy="true">Loading catalog…</p>}>
      <FilterableList products={productsPromise} />
    </Suspense>
  )
}
