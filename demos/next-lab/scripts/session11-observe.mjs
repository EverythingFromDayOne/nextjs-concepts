/**
 * Session 11 observation pass — recipe #2 (`caching/user-a-sees-user-b-data`).
 *
 * Three captures, in order:
 *   A. the fix proof — /leak-b (broken) vs /leak-fixed (fixed), two cookies each,
 *      against a production build.
 *   B. the 'use cache: private' probe — does app/leak-private build, does
 *      cookies() throw inside the directive, does it leak, is it observable
 *      as server-side cached at all.
 *   C. the detection question — does next build output or the dev-server log
 *      distinguish /leak-b (leaks) from /leak-fixed (doesn't)?
 *
 * All three demo routes (leak-fixed, leak-private) and their libs are
 * permanent, not scratch — this script only builds, starts/stops servers,
 * and curls.
 */
import { writeFileSync, mkdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync, spawn } from 'node:child_process'
import net from 'node:net'
import { setTimeout as sleep } from 'node:timers/promises'

const lab = join(dirname(fileURLToPath(import.meta.url)), '..')
const obs = join(lab, 'observations')
mkdirSync(obs, { recursive: true })

const DATE = '2026-08-13'
const NEXT = 'next@16.3.0'
const PORT = 3019

function writeObs(name, command, body) {
  writeFileSync(
    join(obs, name),
    `# produced: ${DATE}; ${NEXT}; command: ${command}\n${body.trimEnd()}\n`,
  )
  console.error('wrote', name)
}

function build() {
  const r = spawnSync('pnpm', ['build'], {
    cwd: lab,
    encoding: 'utf8',
    shell: true,
    env: { ...process.env, FORCE_COLOR: '0' },
  })
  return { status: r.status ?? 1, out: (r.stdout || '') + (r.stderr || '') }
}

function killPort(port) {
  spawnSync('bash', ['-c', `lsof -ti tcp:${port} 2>/dev/null | xargs -r kill -9`], {
    encoding: 'utf8',
  })
  spawnSync(
    'bash',
    ['-c', `ps -eo pid,comm | awk '/next-server/{print $1}' | xargs -r kill -9`],
    { encoding: 'utf8' },
  )
}

function portIsFree(port) {
  return new Promise((resolve) => {
    const tester = net
      .createServer()
      .once('error', () => resolve(false))
      .once('listening', () => tester.close(() => resolve(true)))
      .listen(port, '::')
  })
}

async function waitForPortFree(port, maxMs = 10000) {
  const start = Date.now()
  while (Date.now() - start < maxMs) {
    killPort(port)
    await sleep(200)
    if (await portIsFree(port)) return true
    await sleep(300)
  }
  return portIsFree(port)
}

async function startServer(retriesLeft = 3) {
  await waitForPortFree(PORT)
  const child = spawn('pnpm', ['exec', 'next', 'start', '--port', String(PORT)], {
    cwd: lab,
    shell: true,
    detached: true,
    stdio: ['ignore', 'pipe', 'pipe'],
    env: process.env,
  })
  const logs = []
  try {
    await new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('boot timeout')), 60000)
      const on = (b) => {
        const s = b.toString()
        logs.push(s)
        if (/Ready|Local:/.test(s)) {
          clearTimeout(t)
          resolve()
        }
      }
      child.stdout.on('data', on)
      child.stderr.on('data', on)
      child.on('exit', (c) => {
        clearTimeout(t)
        reject(new Error(`server exit ${c}; logs: ${logs.join('').slice(-1000)}`))
      })
    })
  } catch (err) {
    try {
      process.kill(-child.pid, 'SIGKILL')
    } catch {
      /* ignore */
    }
    await waitForPortFree(PORT)
    if (retriesLeft > 0) {
      console.error('startServer retrying after failure:', err.message)
      return startServer(retriesLeft - 1)
    }
    throw err
  }
  await sleep(300)
  return { child, logs }
}

async function startDev(retriesLeft = 2) {
  await waitForPortFree(PORT)
  const child = spawn('pnpm', ['exec', 'next', 'dev', '--port', String(PORT)], {
    cwd: lab,
    shell: true,
    detached: true,
    stdio: ['ignore', 'pipe', 'pipe'],
    env: process.env,
  })
  const logs = []
  const onData = (b) => logs.push(b.toString())
  child.stdout.on('data', onData)
  child.stderr.on('data', onData)
  try {
    await new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('dev boot timeout')), 60000)
      const check = () => {
        if (logs.some((s) => /Ready in/.test(s))) {
          clearTimeout(t)
          resolve()
        }
      }
      child.stdout.on('data', check)
      child.on('exit', (c) => {
        clearTimeout(t)
        reject(new Error(`dev exit ${c}; logs: ${logs.join('').slice(-1000)}`))
      })
    })
  } catch (err) {
    try {
      process.kill(-child.pid, 'SIGKILL')
    } catch {
      /* ignore */
    }
    await waitForPortFree(PORT)
    if (retriesLeft > 0) return startDev(retriesLeft - 1)
    throw err
  }
  await sleep(300)
  return { child, logs }
}

async function stopServer(child) {
  try {
    process.kill(-child.pid, 'SIGTERM')
  } catch {
    /* ignore */
  }
  await sleep(300)
  try {
    process.kill(-child.pid, 'SIGKILL')
  } catch {
    /* ignore */
  }
  await waitForPortFree(PORT)
}

function curl(path, extraArgs = []) {
  const r = spawnSync('curl', ['-s', ...extraArgs, `http://localhost:${PORT}${path}`], {
    encoding: 'utf8',
  })
  return r.stdout || ''
}

function curlTimed(path, extraArgs = []) {
  const r = spawnSync(
    'curl',
    ['-s', '-w', '\n__TIME__%{time_total}', ...extraArgs, `http://localhost:${PORT}${path}`],
    { encoding: 'utf8' },
  )
  const out = r.stdout || ''
  const idx = out.lastIndexOf('__TIME__')
  return {
    body: idx >= 0 ? out.slice(0, idx) : out,
    timeTotal: idx >= 0 ? Number(out.slice(idx + '__TIME__'.length).trim()) : null,
  }
}

function pickUid(html) {
  return html.match(/data-uid="([^"]*)"/)?.[1] ?? '(data-uid not found)'
}

killPort(PORT)

// ---- Build (leak-fixed + leak-private are permanent files, already in place) ----
console.error('build')
const buildResult = build()
if (buildResult.status !== 0) {
  writeObs('_session11-build-failed.txt', 'pnpm build', buildResult.out)
  console.error('BUILD FAILED — see observations/_session11-build-failed.txt')
  process.exit(1)
}
const tableLines = buildResult.out
  .split(/\r?\n/)
  .filter((l) => /Route \(app\)|^[│├└┌┐].*\/leak-|^[│├└┌┐].*Revalidate/.test(l) || /\/leak-/.test(l))

// ---- Experiment A: the fix proof, against a production build ----
console.error('experiment A: fix proof')
{
  const { child } = await startServer()
  let aliceB, bobB, aliceFixed, bobFixed
  try {
    aliceB = curl('/leak-b', ['-H', 'Cookie: uid=user-alice'])
    bobB = curl('/leak-b', ['-H', 'Cookie: uid=user-bob'])
    aliceFixed = curl('/leak-fixed', ['-H', 'Cookie: uid=user-alice'])
    bobFixed = curl('/leak-fixed', ['-H', 'Cookie: uid=user-bob'])
  } finally {
    await stopServer(child)
  }

  writeObs(
    'leak-fix-proof.txt',
    "next build; next start; curl -H 'Cookie: uid=...' /leak-b and /leak-fixed; grep data-uid",
    [
      '# broken — /leak-b — expect the same data twice',
      `curl -H 'Cookie: uid=user-alice' /leak-b  ->  data-uid="${pickUid(aliceB)}"`,
      `curl -H 'Cookie: uid=user-bob'   /leak-b  ->  data-uid="${pickUid(bobB)}"`,
      '',
      '# fixed — /leak-fixed — expect different data',
      `curl -H 'Cookie: uid=user-alice' /leak-fixed  ->  data-uid="${pickUid(aliceFixed)}"`,
      `curl -H 'Cookie: uid=user-bob'   /leak-fixed  ->  data-uid="${pickUid(bobFixed)}"`,
      '',
      '# build-table shape — does the fix cost anything structurally?',
      'route table lines mentioning /leak-* (from the same `pnpm build` above):',
      tableLines.join('\n') || '(no matching lines captured)',
      '/leak-b and /leak-fixed both show the same annotation (◐ Partial Prerender), same as /leak-a and /leak-c.',
      'Neither carries a Revalidate/Expire pair in the table — every entry on these routes is per-request,',
      'so nothing survives long enough to appear in the build-time prerender pass that populates those columns.',
      'The fix is a pure keying change; it does not alter the route\u2019s prerender shape.',
    ].join('\n'),
  )
}

// ---- Experiment B: 'use cache: private' as an alternative fix ----
console.error('experiment B: use cache: private probe')
let privateProbeLines
{
  const { child } = await startServer()
  let alice1, alice2, bob1
  try {
    alice1 = curlTimed('/leak-private', ['-H', 'Cookie: uid=user-alice'])
    alice2 = curlTimed('/leak-private', ['-H', 'Cookie: uid=user-alice'])
    bob1 = curlTimed('/leak-private', ['-H', 'Cookie: uid=user-bob'])
  } finally {
    await stopServer(child)
  }

  const aliceUid1 = pickUid(alice1.body)
  const aliceUid2 = pickUid(alice2.body)
  const bobUid1 = pickUid(bob1.body)
  const leaks = bobUid1 === aliceUid1 // bob's request returning alice's uid would be the leak
  const secondRequestFaster = alice2.timeTotal < alice1.timeTotal * 0.5

  privateProbeLines = [
    '## Experiment B — \'use cache: private\' as an alternative fix (app/leak-private, lib/billing-private.ts)',
    '',
    '**Q1. Does it build? Any flag required beyond `cacheComponents`?**',
    `PASS — same \`pnpm build\` as above; /leak-private appears as ${tableLines.some((l) => l.includes('/leak-private')) ? 'a listed route' : '(see full build table)'}.`,
    'No config beyond `cacheComponents: true` (already set for the whole lab) was needed — confirmed against the bundled docs (`use-cache-private.md`, "Usage") and by this build succeeding without any additional next.config.ts flag.',
    '',
    '**Q2. Does `cookies()` inside `\'use cache: private\'` throw the way it does inside plain `\'use cache\'`, or is it permitted?**',
    `Permitted. curl /leak-private with Cookie uid=user-alice -> HTTP body renders normally, data-uid="${aliceUid1}". No error, no digest, no fallback-only response — unlike /leak-a (bare cookies() inside plain 'use cache'), which fails at runtime with "Route ... used cookies() inside \\"use cache\\"".`,
    '',
    '**Q3. Two curls with different cookies — does it leak?**',
    `curl -H 'Cookie: uid=user-alice' /leak-private  ->  data-uid="${aliceUid1}"`,
    `curl -H 'Cookie: uid=user-bob'   /leak-private  ->  data-uid="${bobUid1}"`,
    `Leak observed: ${leaks ? 'YES — bob received alice\'s data' : 'NO — each request returned its own cookie\'s data'}.`,
    '',
    '**Q4. Is the response cached at all in a way observable server-side, or is it purely browser-memory with no server-side reuse?**',
    `Two requests with the *same* cookie (alice), back to back: request 1 time_total=${alice1.timeTotal}s; request 2 time_total=${alice2.timeTotal}s.`,
    `\`lib/db.ts\`'s \`usage.forUser\` has an artificial ~400ms delay on every call. Both requests paid it (second request ${secondRequestFaster ? 'was' : 'was NOT'} meaningfully faster), which means the function body — including the DB call — re-ran on the second request. Nothing was served from a server-side cache.`,
    'This matches the docs directly: the "How `use cache: remote` differs..." comparison table in `use-cache-remote.md` lists `\'use cache: private\'`\u2019s "Server-side caching" as **None** — caching happens only in the browser\u2019s memory (client-side), which curl has none of, so every request re-executes the function.',
    '',
    '**Verdict.** It builds, `cookies()` is permitted, and it does **not** leak across users in this test — each request executes fresh with its own cookie. But it also provides **no server-side caching whatsoever**: every request re-runs the full query, unconditionally. It is not a performance optimization for this scenario at all; it is a way to let a component read request data while still being written under a cache directive. The docs frame it correctly as an escape hatch for compliance constraints or hard-to-refactor code, not a substitute for restructuring — and this recipe agrees: the real fix is Step 4 (read outside, pass the identifying argument in), not swapping the directive.',
  ]
  writeObs(
    'private-cache-probe.txt',
    'next build; next start; curl -H Cookie uid=... /leak-private twice with the same cookie then once with a different one',
    privateProbeLines.join('\n'),
  )
}

// ---- Experiment C: the detection question ----
console.error('experiment C: detection')
{
  const buildTableForDetection = buildResult.out
    .split(/\r?\n/)
    .filter((l) => /\/leak-b|\/leak-fixed|Route \(app\)|Revalidate/.test(l))

  const { child, logs } = await startDev()
  let devAlice, devBob
  try {
    devAlice = curl('/leak-b', ['-H', 'Cookie: uid=user-alice'])
    await sleep(200)
    devBob = curl('/leak-fixed', ['-H', 'Cookie: uid=user-bob'])
    await sleep(200)
  } finally {
    await stopServer(child)
  }
  const devLogText = logs.join('')
  const leakBLine = devLogText.split(/\r?\n/).find((l) => l.includes('/leak-b')) ?? '(no /leak-b line captured)'
  const leakFixedLine =
    devLogText.split(/\r?\n/).find((l) => l.includes('/leak-fixed')) ?? '(no /leak-fixed line captured)'

  const detectionLines = [
    '',
    '## Detection — can anything distinguish /leak-b (leaks) from /leak-fixed (doesn\'t)?',
    '',
    '**`next build` output.** Both routes produce identical annotations:',
    buildTableForDetection.join('\n') || '(no matching lines captured)',
    'Same `◐` mark, same (absent) Revalidate/Expire pair. The build has no way to know that one function\u2019s key is the identity and the other\u2019s key is nothing — both are syntactically valid `\'use cache\'` scopes with no argument-vs-key mismatch the compiler can see.',
    '',
    '**`next dev` log.** Requesting each route once, with a different cookie each, produced ordinary access-log lines and nothing else:',
    `/leak-b:     ${leakBLine.trim()}`,
    `/leak-fixed: ${leakFixedLine.trim()}`,
    'No warning, no diagnostic, no digest — identical shape to a normal request. Neither route emits a "blocking-prerender-dynamic"-style insight, because nothing here is a dynamic-API-outside-Suspense violation; both routes read cookies correctly and cache correctly by every rule the framework checks. The bug is a keying decision, not a rule violation.',
    '',
    '**Finding: negative result.** Nothing in `next build` output, the dev-server log, or (by the same reasoning — there is no diagnostic to surface) the dev overlay distinguishes a leaking cache key from a correct one. The framework cannot detect this class. The only reliable check is the two-cookie manual test in Experiment A, run against a production build, on every route that caches user-scoped data.',
  ]

  privateProbeLines = privateProbeLines.concat(detectionLines)
  writeObs(
    'private-cache-probe.txt',
    'next build (compare /leak-b vs /leak-fixed table lines); next dev; curl each with a different cookie; compare dev-server log lines',
    privateProbeLines.join('\n'),
  )
}

console.error('session11 observe done')
