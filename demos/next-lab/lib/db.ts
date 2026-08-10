/**
 * In-memory data layer for the demo lab.
 *
 * Deliberately not an ORM: Wave 1 is about cache boundaries, the ORM
 * decision (roadmap §7.2) is still open, and CI should not need a database.
 * A real ORM arrives in article 44, where it is the subject rather than
 * scenery.
 *
 * Latency is artificial and load-bearing — without it, streaming holes
 * resolve too fast to observe in a browser.
 */

export type Product = {
  id: string
  slug: string
  name: string
  description: string
  priceCents: number
}

export type Plan = { id: string; name: string; priceCents: number }
export type Usage = { uid: string; requests: number; storageMb: number }
export type Alert = { id: string; level: 'info' | 'warn'; message: string }
export type Announcement = { id: string; title: string }
export type ReportSummary = { week: string; totalCents: number; orders: number }
export type Row = { label: string; value: string }

const PRODUCTS: Product[] = [
  { id: 'p1', slug: 'aeron-chair', name: 'Aeron Chair', description: 'Mesh task chair.', priceCents: 149500 },
  { id: 'p2', slug: 'standing-desk', name: 'Standing Desk', description: 'Electric sit-stand desk.', priceCents: 89900 },
  { id: 'p3', slug: 'monitor-arm', name: 'Monitor Arm', description: 'Gas-spring single arm.', priceCents: 12900 },
  { id: 'p4', slug: 'keyboard-tray', name: 'Keyboard Tray', description: 'Under-desk sliding tray.', priceCents: 7900 },
]

const PLANS: Plan[] = [
  { id: 'free', name: 'Free', priceCents: 0 },
  { id: 'pro', name: 'Pro', priceCents: 2900 },
  { id: 'team', name: 'Team', priceCents: 9900 },
]

const USAGE: Record<string, Usage> = {
  'user-alice': { uid: 'user-alice', requests: 18_402, storageMb: 512 },
  'user-bob': { uid: 'user-bob', requests: 233, storageMb: 12 },
}

const SUMMARY: ReportSummary = { week: '2026-W32', totalCents: 4_812_900, orders: 1_284 }

function after<T>(ms: number, value: T): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(value), ms))
}

export const db = {
  products: {
    findBySlug: (slug: string) => after(120, PRODUCTS.find((p) => p.slug === slug) ?? null),
    findByIds: (ids: string[]) => after(120, PRODUCTS.filter((p) => ids.includes(p.id))),
    findMany: () => after(150, PRODUCTS),
    allSlugs: () => after(20, PRODUCTS.map((p) => p.slug)),
  },
  inventory: {
    // Deliberately slow: this is the streamed hole in article 1.
    forSlug: (slug: string) => after(700, (slug.length * 7) % 13),
  },
  plans: {
    findMany: () => after(180, PLANS),
  },
  usage: {
    forUser: (uid: string) => after(400, USAGE[uid] ?? { uid, requests: 0, storageMb: 0 }),
  },
  alerts: {
    findMany: () =>
      after(250, [
        { id: 'a1', level: 'info', message: 'Scheduled maintenance Sunday.' },
      ] satisfies Alert[]),
  },
  announcements: {
    findMany: () =>
      after(80, [
        { id: 'n1', title: 'Welcome to the lab' },
        { id: 'n2', title: 'Cache Components is on' },
      ] satisfies Announcement[]),
  },
  report: {
    // cached by lib/report.ts — resolves during the prerender
    summary: () => after(150, SUMMARY),
    // uncached, deliberately, and deliberately at three different speeds
    revenue: () =>
      after(200, [
        { label: 'Subscriptions', value: '$28,140' },
        { label: 'One-off', value: '$14,220' },
        { label: 'Refunds', value: '-$1,431' },
      ] satisfies Row[]),
    traffic: () =>
      after(600, [
        { label: 'Sessions', value: '84,201' },
        { label: 'Signups', value: '1,905' },
        { label: 'Bounce', value: '41%' },
        { label: 'Median TTFB', value: '180ms' },
      ] satisfies Row[]),
    errors: () =>
      after(1500, [
        { label: '5xx', value: '12' },
        { label: '4xx', value: '3,904' },
      ] satisfies Row[]),
  },
}

export function formatPrice(cents: number) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(cents / 100)
}
