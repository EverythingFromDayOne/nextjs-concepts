import { formatPrice } from '@/lib/db'
import { getPlans } from '@/lib/billing'
import { setPriceWithRevalidate, setPriceWithUpdate } from './actions'

export default async function TagsPage() {
  const plans = await getPlans()
  const pro = plans.find((p) => p.id === 'pro')

  return (
    <main>
      <h1>Tags and invalidation</h1>
      <p>
        Pro price:{' '}
        <span data-plan="pro" data-price-cents={pro?.priceCents ?? ''}>
          {pro ? formatPrice(pro.priceCents) : 'missing'}
        </span>
      </p>
      <ul>
        {plans.map((p) => (
          <li key={p.id} data-plan={p.id} data-price-cents={p.priceCents}>
            {p.name}: {formatPrice(p.priceCents)}
          </li>
        ))}
      </ul>

      <form action={setPriceWithUpdate} data-action="updateTag">
        <h2>updateTag</h2>
        <input type="hidden" name="id" value="pro" />
        <label>
          cents
          <input name="cents" type="number" defaultValue={3100} />
        </label>
        <button type="submit">Save with updateTag</button>
      </form>

      <form action={setPriceWithRevalidate} data-action="revalidateTag">
        <h2>revalidateTag</h2>
        <input type="hidden" name="id" value="pro" />
        <label>
          cents
          <input name="cents" type="number" defaultValue={3300} />
        </label>
        <button type="submit">Save with revalidateTag</button>
      </form>
    </main>
  )
}
