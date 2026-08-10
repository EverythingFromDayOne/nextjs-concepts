import { Suspense } from 'react'
import { notFound } from 'next/navigation'
import { getProduct, getPrerenderedSlugs } from '@/lib/catalog'
import { formatPrice } from '@/lib/db'
import { AddToCart } from './add-to-cart'
import { Inventory } from './inventory'
import { RecentlyViewed } from './recently-viewed'
import { PriceAsOf } from './price-as-of'
import {
  ProductHeaderSkeleton,
  InventorySkeleton,
  RecentlyViewedSkeleton,
} from './skeletons'

export async function generateStaticParams() {
  const slugs = await getPrerenderedSlugs()
  // Deliberately a subset: the remaining slug exercises shell-then-upgrade.
  return slugs.slice(0, 3).map((slug) => ({ slug }))
}

// Note: this component is NOT async and awaits nothing. Its entire job is
// to declare where the shell ends and the holes begin.
export default function Page({ params }: PageProps<'/products/[slug]'>) {
  return (
    <main>
      <Suspense fallback={<ProductHeaderSkeleton />}>
        <ProductHeader params={params} />
      </Suspense>

      <Suspense fallback={<InventorySkeleton />}>
        <Inventory params={params} />
      </Suspense>

      <Suspense fallback={null}>
        <PriceAsOf />
      </Suspense>

      <Suspense fallback={<RecentlyViewedSkeleton />}>
        <RecentlyViewed />
      </Suspense>
    </main>
  )
}

async function ProductHeader({
  params,
}: Pick<PageProps<'/products/[slug]'>, 'params'>) {
  // params is awaited HERE, inside the boundary, not at the top of Page.
  const { slug } = await params
  const product = await getProduct(slug)
  if (!product) notFound()

  return (
    <header>
      <h1>{product.name}</h1>
      <p>{product.description}</p>
      <strong>{formatPrice(product.priceCents)}</strong>
      <AddToCart productId={product.id} />
    </header>
  )
}
