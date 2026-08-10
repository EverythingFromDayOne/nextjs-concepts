'use client'

// client: owns filter state AND unwraps a streamed promise
import { use, useState } from 'react'
import type { Product } from '@/lib/db'
import { formatPrice } from '@/lib/db'

export function FilterableList({ products }: { products: Promise<Product[]> }) {
  const list = use(products)
  const [filter, setFilter] = useState('')
  const visible = list.filter((p) =>
    p.name.toLowerCase().includes(filter.toLowerCase())
  )

  return (
    <>
      <input
        value={filter}
        placeholder="Filter…"
        onChange={(e) => setFilter(e.target.value)}
      />
      <ul>
        {visible.map((p) => (
          <li key={p.id}>{p.name} — {formatPrice(p.priceCents)}</li>
        ))}
      </ul>
    </>
  )
}
