import { Suspense } from 'react'
import { after, connection } from 'next/server'
import { recordView } from '@/lib/audit'

export default function AfterDemoPage() {
  return (
    <main>
      <Suspense fallback={<p aria-busy="true">Sending…</p>}>
        <AfterBody />
      </Suspense>
    </main>
  )
}

async function AfterBody() {
  await connection()
  const queuedAt = Date.now()

  // Scheduled now, executed after the response has been sent. The 300ms
  // write does not appear in the visitor's total.
  after(() => recordView('/after-demo', queuedAt))

  console.log(`[render] /after-demo responded at ${Date.now()}`)

  return <h1>Response sent; audit still pending.</h1>
}
