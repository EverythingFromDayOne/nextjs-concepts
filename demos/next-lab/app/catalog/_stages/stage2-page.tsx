// STAGE 2 — server data, client filter. Waterfall and API route gone, but
// every product now crosses the boundary as a serialized prop.
import { getAllProducts } from '@/lib/catalog'
import { Stage2List } from './stage2-list'

export async function Stage2CatalogPage() {
  const products = await getAllProducts()
  return <Stage2List products={products} />
}
