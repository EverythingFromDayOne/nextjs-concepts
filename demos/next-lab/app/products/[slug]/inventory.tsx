import { getLiveStock } from '@/lib/inventory'

export async function Inventory({
  params,
}: Pick<PageProps<'/products/[slug]'>, 'params'>) {
  const { slug } = await params
  const stock = await getLiveStock(slug)

  return stock > 0 ? <p>{stock} in stock</p> : <p>Out of stock</p>
}
