import type { Product } from '@/lib/db'
import { formatPrice } from '@/lib/db'

// Server Component. Passed into FilterShell as children, never imported
// by it — which is why it stays out of the client bundle.
export function ProductRow({ product }: { product: Product }) {
  return (
    <li>
      {product.name} — {formatPrice(product.priceCents)}
    </li>
  )
}
