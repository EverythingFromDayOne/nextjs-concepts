#!/usr/bin/env node
/**
 * Experiment A — updateTag vs revalidateTag on /tags (progressive form POST).
 * Captures before / action-response / next-request for each function.
 */
import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

const BASE = process.env.BASE_URL ?? 'http://127.0.0.1:3015'
const OUT = resolve(process.cwd(), 'observations/tag-invalidation-semantics.txt')

function proCents(html) {
  const m = html.match(/data-plan="pro"\s+data-price-cents="(\d+)"/)
  return m ? Number(m[1]) : null
}

function actionIds(html) {
  const ids = []
  for (const m of html.matchAll(/name="\$ACTION_ID_([a-f0-9]+)"/g)) ids.push(m[1])
  return ids
}

async function get(path = '/tags') {
  const t0 = performance.now()
  const res = await fetch(`${BASE}${path}`)
  const body = await res.text()
  return { status: res.status, body, ms: performance.now() - t0, cents: proCents(body) }
}

async function postAction(actionId, fields) {
  const fd = new FormData()
  fd.set(`$ACTION_ID_${actionId}`, '')
  for (const [k, v] of Object.entries(fields)) fd.set(k, String(v))
  const t0 = performance.now()
  const res = await fetch(`${BASE}/tags`, {
    method: 'POST',
    headers: { Origin: BASE },
    body: fd,
    redirect: 'manual',
  })
  const body = await res.text()
  return { status: res.status, body, ms: performance.now() - t0, cents: proCents(body) }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms))
}

async function main() {
  const page = await get()
  const [updateId, revalidateId] = actionIds(page.body)
  if (!updateId || !revalidateId) {
    throw new Error(`action ids missing: ${updateId}, ${revalidateId}`)
  }

  const lines = []
  lines.push(`# produced: ${new Date().toISOString()}; next@16.3.0; BASE=${BASE}`)
  lines.push(`# method: progressive-enhancement multipart POST to /tags (Origin set)`)
  lines.push(`# updateAction=${updateId}`)
  lines.push(`# revalidateAction=${revalidateId}`)
  lines.push('')

  // -------- updateTag leg --------
  // Force known store+cache value via updateTag itself.
  await postAction(updateId, { id: 'pro', cents: 2900 })
  const u1 = await get()
  const u2 = await get()
  const uAct = await postAction(updateId, { id: 'pro', cents: 3100 })
  const uNext = await get()

  lines.push('## setPriceWithUpdate (updateTag)')
  lines.push(
    `warm_confirm: after_reset_ms=${u1.ms.toFixed(1)} second_get_ms=${u2.ms.toFixed(1)} warm=${u2.ms < 50} before_cents=${u2.cents}`,
  )
  lines.push(`before_cents: ${u2.cents}`)
  lines.push(`action_response_cents: ${uAct.cents} (http=${uAct.status}, ms=${uAct.ms.toFixed(1)})`)
  lines.push(`next_request_cents: ${uNext.cents} (ms=${uNext.ms.toFixed(1)})`)
  lines.push('')

  // -------- revalidateTag leg --------
  await postAction(updateId, { id: 'pro', cents: 2900 })
  const r1 = await get()
  const r2 = await get()
  const rAct = await postAction(revalidateId, { id: 'pro', cents: 3300 })
  const rNext1 = await get()
  await sleep(300)
  const rNext2 = await get()
  await sleep(1000)
  const rNext3 = await get()

  lines.push('## setPriceWithRevalidate (revalidateTag(plans, max))')
  lines.push(
    `warm_confirm: after_reset_ms=${r1.ms.toFixed(1)} second_get_ms=${r2.ms.toFixed(1)} warm=${r2.ms < 50} before_cents=${r2.cents}`,
  )
  lines.push(`before_cents: ${r2.cents}`)
  lines.push(`action_response_cents: ${rAct.cents} (http=${rAct.status}, ms=${rAct.ms.toFixed(1)})`)
  lines.push(`next_request_cents: ${rNext1.cents} (ms=${rNext1.ms.toFixed(1)})`)
  lines.push(`next_request_2_cents: ${rNext2.cents} (ms=${rNext2.ms.toFixed(1)})`)
  lines.push(`next_request_3_cents: ${rNext3.cents} (ms=${rNext3.ms.toFixed(1)})`)
  lines.push('')

  lines.push('## six data points')
  lines.push('| function | before | action response | next request |')
  lines.push('| --- | --- | --- | --- |')
  lines.push(`| updateTag | ${u2.cents} | ${uAct.cents} | ${uNext.cents} |`)
  lines.push(`| revalidateTag(..., 'max') | ${r2.cents} | ${rAct.cents} | ${rNext1.cents} |`)
  lines.push('')

  const sameAction = uAct.cents === rAct.cents // both "new" or both "old" relative to their writes
  // Relative to each write target:
  const updateActionFresh = uAct.cents === 3100
  const revalidateActionFresh = rAct.cents === 3300
  const updateNextFresh = uNext.cents === 3100
  const revalidateNextFresh = rNext1.cents === 3300

  lines.push('## interpretation')
  lines.push(
    `updateTag action shows new (3100): ${updateActionFresh}; next shows new: ${updateNextFresh}`,
  )
  lines.push(
    `revalidateTag action shows new (3300): ${revalidateActionFresh}; next shows new: ${revalidateNextFresh}; later shows ${rNext2.cents}/${rNext3.cents}`,
  )
  if (updateActionFresh && revalidateActionFresh && updateNextFresh && !revalidateNextFresh) {
    lines.push(
      'divergence: BOTH action responses rendered the new price; the SWR distinction appeared on the NEXT GET (stale 2900), not in the action response HTML.',
    )
  } else if (updateActionFresh && !revalidateActionFresh) {
    lines.push(
      'divergence: matches the documented read-your-own-writes vs SWR split in the action response itself.',
    )
  } else if (updateActionFresh === revalidateActionFresh && updateNextFresh === revalidateNextFresh) {
    lines.push(
      'identical_behaviour: YES — both functions produced the same before/action/next pattern in this measurement.',
    )
  } else {
    lines.push('divergence: see table; pattern does not match either simple hypothesis cleanly.')
  }

  writeFileSync(OUT, lines.join('\n') + '\n')
  console.log(lines.join('\n'))
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
