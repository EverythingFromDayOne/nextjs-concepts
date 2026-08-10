import { connection } from 'next/server'

export async function PriceAsOf() {
  // Without this line the build fails: new Date() cannot suspend, so the
  // prerender would bake a build-time clock into a static artifact.
  await connection()
  return <p>Prices as of <time>{new Date().toLocaleTimeString('en-US')}</time></p>
}
