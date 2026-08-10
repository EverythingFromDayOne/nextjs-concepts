'use client'

// client: owns the quantity input's local state
import { useState } from 'react'
import { addToCart } from './actions'

export function AddToCart({ productId }: { productId: string }) {
  const [qty, setQty] = useState(1)

  return (
    <form action={addToCart}>
      <input type="hidden" name="productId" value={productId} />
      <input
        type="number"
        name="qty"
        min={1}
        value={qty}
        onChange={(e) => setQty(Number(e.target.value))}
      />
      <button type="submit">Add to cart</button>
    </form>
  )
}
