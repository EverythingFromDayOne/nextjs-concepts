'use client'

// STAGE 1 — the version most people write first, preserved to be measured
// against. Four costs: whole subtree in the client graph, data loads after
// hydration, an API route that exists only for this page, and an empty shell.
import { useEffect, useState } from 'react'
import type { Product } from '@/lib/db'

export function Stage1CatalogPage() {
  const [products, setProducts] = useState<Product[]>([])
  const [filter, setFilter] = useState('')

  useEffect(() => {
    fetch('/api/products')
      .then((r) => r.json())
      .then(setProducts)
  }, [])

  const visible = products.filter((p) => p.name.includes(filter))

  return (
    <>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      <ul>{visible.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
    </>
  )
}
