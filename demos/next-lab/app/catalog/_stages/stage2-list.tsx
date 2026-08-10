'use client'

import { useState } from 'react'
import type { Product } from '@/lib/db'

export function Stage2List({ products }: { products: Product[] }) {
  const [filter, setFilter] = useState('')
  const visible = products.filter((p) => p.name.includes(filter))

  return (
    <>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      <ul>{visible.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
    </>
  )
}
