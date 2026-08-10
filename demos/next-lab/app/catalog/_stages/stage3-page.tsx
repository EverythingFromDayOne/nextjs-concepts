// STAGE 3 — the slot. Rows are rendered on the server and passed through
// the client boundary as children, so they are never bundled.
//
// The trade this makes: the client no longer has the data, so the filter
// cannot re-filter locally. If instant local filtering is required,
// stage 2 is correct and the prop cost is the price.
import { getAllProducts } from '@/lib/catalog'
import { FilterShell } from '../filter-shell'
import { ProductRow } from '../product-row'

export async function Stage3CatalogPage() {
  const products = await getAllProducts()

  return (
    <FilterShell>
      <ul>
        {products.map((p) => <ProductRow key={p.id} product={p} />)}
      </ul>
    </FilterShell>
  )
}
