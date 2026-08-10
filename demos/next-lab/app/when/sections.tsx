import { connection } from 'next/server'
import { getStaticFacts } from '@/lib/when'
import { formatPrice } from '@/lib/db'

/**
 * BUILD TIME. Cached, so it resolves during the prerender and lands in the
 * shell. It deliberately displays no timestamp — a value describing when
 * this ran would be baked into a static artifact and wrong for every
 * visitor after the first. That absence is the lesson.
 */
export async function BuildTimeSection() {
  const facts = await getStaticFacts()
  return (
    <section>
      <h2>Build time</h2>
      <p>{formatPrice(facts.totalCents)} — same for every visitor this hour.</p>
    </section>
  )
}

/**
 * REQUEST TIME. connection() is the explicit abort: "do not prerender past
 * this line." Only after it is new Date() legal, because only then does a
 * request exist for it to describe.
 */
export async function RequestTimeSection() {
  await connection()
  return (
    <section>
      <h2>Request time</h2>
      <p>
        Rendered at <time>{new Date().toISOString()}</time>
      </p>
    </section>
  )
}
