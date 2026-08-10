// legacy: Next <16 implicit-caching model — see docs/evolution-ledger.md
// NOT COMPILED. Excluded from tsconfig. Extraction target only.
export const dynamic = 'force-dynamic'
export const revalidate = 60

import { cookies } from 'next/headers'
import { unstable_cache } from 'next/cache'

const getPlans = unstable_cache(
  async () => db.plans.findMany(),
  ['plans'],
  { revalidate: 3600, tags: ['plans'] }
)

export default async function DashboardPage() {
  const uid = (await cookies()).get('uid')?.value
  const [plans, usage, alerts] = await Promise.all([
    getPlans(),
    db.usage.forUser(uid),
    fetch('https://status.example.com/alerts').then((r) => r.json()),
  ])

  return (
    <main>
      <PlanTable plans={plans} />
      <UsageChart usage={usage} />
      <AlertBanner alerts={alerts} />
      <LastRefreshed at={new Date()} />
    </main>
  )
}
