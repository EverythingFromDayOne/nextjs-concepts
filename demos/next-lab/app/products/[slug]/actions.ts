'use server'

export async function addToCart(formData: FormData) {
  const productId = String(formData.get('productId') ?? '')
  const qty = Number(formData.get('qty') ?? 1)
  if (!productId || qty < 1) return
  // A real implementation authorizes here — a Server Function is a public
  // endpoint, and the UI that called it is not the authorization.
  console.log('[demo] add to cart', { productId, qty })
}
