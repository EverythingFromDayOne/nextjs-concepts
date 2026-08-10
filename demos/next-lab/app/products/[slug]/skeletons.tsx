export function ProductHeaderSkeleton() {
  return <header aria-busy="true"><h1>Loading product…</h1></header>
}

export function InventorySkeleton() {
  return <p aria-busy="true">Checking inventory…</p>
}

export function RecentlyViewedSkeleton() {
  return <section aria-busy="true"><h2>Recently viewed</h2></section>
}
