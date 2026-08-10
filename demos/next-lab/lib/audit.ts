export async function recordView(route: string, at: number) {
  // Stands in for an analytics write or an audit-log insert: work the
  // visitor must never wait for.
  await new Promise((r) => setTimeout(r, 300))
  console.log(`[audit] ${route} viewed, queued at ${at}, written at ${Date.now()}`)
}
