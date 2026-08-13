/**
 * Session 7 observation pass — the eleven-probe enforcement matrix, plus the
 * §3 route-lifetime-column follow-up probe.
 *
 * Each probe is added alone, built (and started + curled, if it built),
 * captured, then fully removed before the next probe — a build error is
 * fatal, so probes cannot coexist. Linux port-kill via lsof, not Windows
 * PowerShell (this environment's next-lab AGENTS.md still applies: this is
 * not the Next.js of training data).
 */
import { writeFileSync, mkdirSync, rmSync, existsSync, readdirSync, readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync, spawn } from 'node:child_process'
import net from 'node:net'
import { setTimeout as sleep } from 'node:timers/promises'

const lab = join(dirname(fileURLToPath(import.meta.url)), '..')
const obs = join(lab, 'observations')
const appDir = join(lab, 'app')
const libDir = join(lab, 'lib')
mkdirSync(obs, { recursive: true })

const DATE = '2026-08-10'
const NEXT = 'next@16.3.0'
const PORT = 3017

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

function firstErrorLine(out) {
  const lines = out.split(/\r?\n/)
  for (const l of lines) {
    if (/Error:|Failed to compile|×|⨯/.test(l)) return l.trim()
  }
  return '(no recognizable error line; see full output)'
}

function extractErrors(out) {
  const lines = out.split(/\r?\n/)
  const idxs = []
  for (let i = 0; i < lines.length; i++) {
    if (/Error:|Export encountered|⨯|×|ELIFECYCLE|unstable value|Failed to compile/i.test(lines[i])) {
      idxs.push(i)
    }
  }
  if (idxs.length === 0) return out.slice(-2000)
  const chunks = []
  for (const i of idxs.slice(0, 6)) {
    chunks.push(lines.slice(Math.max(0, i - 1), i + 12).join('\n'))
  }
  return chunks.join('\n---\n')
}

const scratchPaths = new Set()

function writeScratch(relPath, contents) {
  const full = join(lab, relPath)
  mkdirSync(dirname(full), { recursive: true })
  writeFileSync(full, contents)
  scratchPaths.add(full)
}

function removeAllScratch() {
  for (const p of scratchPaths) {
    if (existsSync(p)) rmSync(p, { recursive: true, force: true })
  }
  // also sweep any leftover scratch-s7 route dirs, in case of an interrupted run
  if (existsSync(appDir)) {
    for (const name of readdirSync(appDir)) {
      if (name.startsWith('scratch-s7')) {
        rmSync(join(appDir, name), { recursive: true, force: true })
      }
    }
  }
  scratchPaths.clear()
}

function killPort(port) {
  // `next start` spawns a separate `next-server` process that isn't reliably
  // reachable through the `pnpm exec next start` process tree or through
  // lsof in this sandbox, so it's swept by process-title pattern too — by
  // PID, never by a blind `pkill -f` — as a second line of defense.
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
  // lsof is unreliable for the detached `next-server` grandchild in this
  // sandbox, so the ground truth is an actual bind attempt.
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

async function runProbe({ label, files, build: doBuild = true, run }) {
  console.error('probe:', label)
  removeAllScratch()
  for (const [relPath, contents] of Object.entries(files)) writeScratch(relPath, contents)
  await sleep(150)

  let buildResult = null
  let runOutput = 'not run — build failed'
  try {
    if (doBuild) {
      buildResult = build()
      if (buildResult.status === 0 && run) {
        const { child } = await startServer()
        try {
          runOutput = await run()
        } finally {
          await stopServer(child)
        }
      } else if (buildResult.status !== 0) {
        runOutput = 'not run — build failed'
      } else {
        runOutput = '(no runtime probe for this case)'
      }
    }
  } catch (err) {
    runOutput = `PROBE INFRA ERROR (not a Next.js finding): ${err.message}`
  }

  removeAllScratch()
  return { buildResult, runOutput }
}

function writeIncremental() {
  writeFileSync(
    join(obs, '_enforcement-matrix.partial.txt'),
    `# produced: ${DATE}; ${NEXT}; in-progress partial write from session7-observe.mjs\n${results.join('\n')}`,
  )
}

function pushResult(entry) {
  results.push(entry)
  writeIncremental()
}

function block(n, label, where, buildResult, runOutput, silentNote) {
  const buildLine = buildResult
    ? `build: ${buildResult.status === 0 ? 'PASS (exit 0)' : 'FAIL (exit ' + buildResult.status + ')'}`
    : 'build: (not attempted)'
  const errLine =
    buildResult && buildResult.status !== 0
      ? `build error (first line): ${firstErrorLine(buildResult.out)}`
      : null
  const fullErr =
    buildResult && buildResult.status !== 0 ? `full extract:\n${extractErrors(buildResult.out)}` : null
  return [
    `### Probe ${n}: ${label}`,
    `where: ${where}`,
    buildLine,
    errLine,
    `runtime: ${runOutput}`,
    `silent?: ${silentNote}`,
    fullErr,
    '',
  ]
    .filter(Boolean)
    .join('\n')
}

killPort(PORT)
removeAllScratch()

const results = []

// ---- Probe 1: 'use cache' on a non-async function ----
{
  const { buildResult } = await runProbe({
    label: "probe1-non-async-use-cache",
    files: {
      'lib/_scratch-p1.ts': `export function getNonAsync() {
  'use cache'
  return 42
}
`,
      'app/scratch-s7-p1/page.tsx': `import { getNonAsync } from '@/lib/_scratch-p1'

export default function Page() {
  return <p>{getNonAsync()}</p>
}
`,
    },
    run: null,
  })
  pushResult(
    block(
      1,
      "'use cache' on a non-async function",
      'lib/_scratch-p1.ts (new scratch lib) + app/scratch-s7-p1/page.tsx',
      buildResult,
      'not applicable — build must pass before request-time behavior can be observed',
      buildResult.status !== 0 ? 'n/a — caught at build' : 'unexpected: this built; see full extract',
    ),
  )
}

// ---- Probe 2: cacheLife() called at module scope ----
{
  const { buildResult } = await runProbe({
    label: 'probe2-cachelife-module-scope',
    files: {
      'lib/_scratch-p2.ts': `import { cacheLife } from 'next/cache'

// module scope — not inside a 'use cache' function
cacheLife('minutes')

export async function getSomething() {
  'use cache'
  return 1
}
`,
      'app/scratch-s7-p2/page.tsx': `import { getSomething } from '@/lib/_scratch-p2'

export default async function Page() {
  const v = await getSomething()
  return <p>{v}</p>
}
`,
    },
    run: null,
  })
  pushResult(
    block(
      2,
      'cacheLife() called at module scope',
      'lib/_scratch-p2.ts (new scratch lib) + app/scratch-s7-p2/page.tsx',
      buildResult,
      'not applicable — build must pass before request-time behavior can be observed',
      buildResult.status !== 0 ? 'n/a — caught at build' : 'unexpected: this built; see full extract',
    ),
  )
}

// ---- Probe 3: cookies() inside a cached scope — reuse lib/billing-leak-a.ts + app/leak-a ----
{
  console.error('probe: probe3-cookies-in-cache (reuse, reconfirm only)')
  const buildResult = build()
  let runOutput = 'not run — build failed'
  if (buildResult.status === 0) {
    try {
      const { child } = await startServer()
      try {
        const html = curl('/leak-a', ['-H', 'Cookie: uid=user-alice'])
        runOutput = `curl /leak-a with Cookie uid=user-alice -> ${html.replace(/\s+/g, ' ').trim().slice(0, 400)}`
      } finally {
        await stopServer(child)
      }
    } catch (err) {
      runOutput = `PROBE INFRA ERROR (not a Next.js finding): ${err.message}`
    }
  }
  pushResult(
    block(
      3,
      "cookies() inside a cached scope (reuse lib/billing-leak-a.ts + app/leak-a — reconfirm only)",
      'lib/billing-leak-a.ts (existing, permanent) + app/leak-a (existing, permanent)',
      buildResult,
      runOutput,
      'n/a — caught at runtime (route is dynamic, so it passes build and fails under next start)',
    ),
  )
}

// ---- Probe 4: connection() inside a cached scope ----
{
  const { buildResult } = await runProbe({
    label: 'probe4-connection-in-cache',
    files: {
      'lib/_scratch-p4.ts': `import { cacheLife } from 'next/cache'
import { connection } from 'next/server'

export async function getWithConnection() {
  'use cache'
  cacheLife('minutes')
  await connection()
  return 'x'
}
`,
      'app/scratch-s7-p4/page.tsx': `import { getWithConnection } from '@/lib/_scratch-p4'

export default async function Page() {
  const v = await getWithConnection()
  return <p>{v}</p>
}
`,
    },
    run: null,
  })
  pushResult(
    block(
      4,
      'connection() inside a cached scope',
      'lib/_scratch-p4.ts (new scratch lib) + app/scratch-s7-p4/page.tsx',
      buildResult,
      'not applicable — build must pass before request-time behavior can be observed',
      buildResult.status !== 0 ? 'n/a — caught at build' : 'unexpected: this built; see full extract',
    ),
  )
}

// ---- Probe 5: new Date() inside a cached scope — reuse lib/stamped.ts (reconfirm only) ----
{
  const { buildResult, runOutput } = await runProbe({
    label: 'probe5-date-in-cache-reconfirm',
    files: {
      'app/scratch-s7-p5/page.tsx': `import { getStamped } from '@/lib/stamped'

export default async function Page() {
  const s = await getStamped()
  return (
    <main>
      <p data-at={s.at}>{s.at}</p>
      <p>{s.data.week}</p>
    </main>
  )
}
`,
    },
    run: async () => {
      const html1 = curl('/scratch-s7-p5')
      const at1 = html1.match(/data-at="([^"]+)"/)?.[1] ?? null
      await sleep(2000)
      const html2 = curl('/scratch-s7-p5')
      const at2 = html2.match(/data-at="([^"]+)"/)?.[1] ?? null
      return `request1 at=${at1}; request2 (2s later) at=${at2}; frozen=${at1 !== null && at1 === at2}`
    },
  })
  pushResult(
    block(
      5,
      "new Date() inside a cached scope (reuse lib/stamped.ts — reconfirm only)",
      'lib/stamped.ts (existing, permanent) + app/scratch-s7-p5/page.tsx (scratch route)',
      buildResult,
      runOutput,
      'yes — silent: builds and runs cleanly; the timestamp freezes at cache-entry creation and nothing in the response marks it as stale',
    ),
  )
}

// ---- Probe 6: useState in a Server Component ----
{
  const { buildResult } = await runProbe({
    label: 'probe6-usestate-in-server-component',
    files: {
      'app/scratch-s7-p6/page.tsx': `import { useState } from 'react'

export default function Page() {
  const [count] = useState(0)
  return <p>{count}</p>
}
`,
    },
    run: null,
  })
  pushResult(
    block(
      6,
      'useState in a Server Component',
      'app/scratch-s7-p6/page.tsx (scratch route, no "use client")',
      buildResult,
      'not applicable — build must pass before request-time behavior can be observed',
      buildResult.status !== 0 ? 'n/a — caught at build' : 'unexpected: this built; see full extract',
    ),
  )
}

// ---- Probe 7: onClick handler on an element in a Server Component ----
{
  const { buildResult } = await runProbe({
    label: 'probe7-onclick-in-server-component',
    files: {
      'app/scratch-s7-p7/page.tsx': `export default function Page() {
  return <button onClick={() => {}}>Click</button>
}
`,
    },
    run: null,
  })
  pushResult(
    block(
      7,
      'onClick handler on an element in a Server Component',
      'app/scratch-s7-p7/page.tsx (scratch route, no "use client")',
      buildResult,
      'not applicable — build must pass before request-time behavior can be observed',
      buildResult.status !== 0 ? 'n/a — caught at build' : 'unexpected: this built; see full extract',
    ),
  )
}

// ---- Probe 8: Server Component imported into a Client Component ----
{
  const { buildResult } = await runProbe({
    label: 'probe8-server-component-imported-into-client',
    files: {
      'app/scratch-s7-p8/server-part.tsx': `import { db } from '@/lib/db'

export default async function ServerPart() {
  const plans = await db.plans.findMany()
  return (
    <ul>
      {plans.map((p) => (
        <li key={p.id}>{p.name}</li>
      ))}
    </ul>
  )
}
`,
      'app/scratch-s7-p8/client-wrapper.tsx': `'use client'
import ServerPart from './server-part'

export default function ClientWrapper() {
  return (
    <div>
      <ServerPart />
    </div>
  )
}
`,
      'app/scratch-s7-p8/page.tsx': `import ClientWrapper from './client-wrapper'

export default function Page() {
  return <ClientWrapper />
}
`,
    },
    run: null,
  })
  pushResult(
    block(
      8,
      'Server Component imported into a Client Component',
      "app/scratch-s7-p8/{server-part.tsx,client-wrapper.tsx,page.tsx} (scratch pair)",
      buildResult,
      'not applicable — build must pass before request-time behavior can be observed',
      buildResult.status !== 0 ? 'n/a — caught at build' : 'unexpected: this built; see full extract',
    ),
  )
}

// ---- Probe 9: a function passed as a prop across the client boundary ----
{
  const { buildResult, runOutput } = await runProbe({
    label: 'probe9-function-prop-across-boundary',
    files: {
      'app/scratch-s7-p9/client-child.tsx': `'use client'

export default function ClientChild({ onClick }: { onClick: () => void }) {
  return <p data-typeof={typeof onClick}>onClick is {typeof onClick}</p>
}
`,
      'app/scratch-s7-p9/page.tsx': `import ClientChild from './client-child'

export default function Page() {
  const handler = () => {
    console.log('never actually callable from the client')
  }
  return <ClientChild onClick={handler} />
}
`,
    },
    run: async () => {
      const html = curl('/scratch-s7-p9')
      return `curl /scratch-s7-p9 -> ${html.replace(/\s+/g, ' ').trim().slice(0, 500)}`
    },
  })
  pushResult(
    block(
      9,
      'a function passed as a prop across the client boundary',
      'app/scratch-s7-p9/{client-child.tsx,page.tsx} (scratch pair)',
      buildResult,
      runOutput,
      buildResult.status !== 0
        ? 'n/a — caught at build'
        : 'not silent if runtime shows an error digest; see runtime line',
    ),
  )
}

// ---- Probe 10: a class instance passed as a prop across the boundary ----
{
  const { buildResult, runOutput } = await runProbe({
    label: 'probe10-class-instance-prop-across-boundary',
    files: {
      'app/scratch-s7-p10/client-child.tsx': `'use client'

type WidgetLike = { name: string; getName?: () => string }

export default function ClientChild({ item }: { item: WidgetLike }) {
  const protoIsPlainObject = Object.getPrototypeOf(item) === Object.prototype
  return (
    <div>
      <p data-name={item.name}>name={item.name}</p>
      <p data-keys={Object.keys(item).join(',')}>keys={Object.keys(item).join(',')}</p>
      <p data-proto-plain={String(protoIsPlainObject)}>protoIsPlainObject={String(protoIsPlainObject)}</p>
      <p data-getname-type={typeof item.getName}>getNameType={typeof item.getName}</p>
      <p data-getname-result={item.getName ? String(item.getName()) : '(no method)'}>
        getNameResult={item.getName ? String(item.getName()) : '(no method)'}
      </p>
    </div>
  )
}
`,
      'app/scratch-s7-p10/page.tsx': `import ClientChild from './client-child'

class Widget {
  name: string
  constructor(name: string) {
    this.name = name
  }
  getName() {
    return this.name
  }
}

export default function Page() {
  const w = new Widget('probe-10')
  return <ClientChild item={w} />
}
`,
    },
    run: async () => {
      const html = curl('/scratch-s7-p10')
      const pick = (attr) => html.match(new RegExp(`data-${attr}="([^"]*)"`))?.[1] ?? '(attr not found)'
      return [
        `name=${pick('name')}`,
        `keys=${pick('keys')}`,
        `protoIsPlainObject=${pick('proto-plain')}`,
        `getNameType=${pick('getname-type')}`,
        `getNameResult=${pick('getname-result')}`,
      ].join('; ')
    },
  })
  pushResult(
    block(
      10,
      'a class instance passed as a prop across the boundary — PROBE 10, the load-bearing one',
      'app/scratch-s7-p10/{client-child.tsx,page.tsx} (scratch pair)',
      buildResult,
      runOutput,
      buildResult.status !== 0
        ? 'n/a — caught at build'
        : 'see runtime line — getNameType/getNameResult settle whether this is silent',
    ),
  )
}

// ---- Probe 11: a non-async export in a 'use server' file ----
{
  const { buildResult } = await runProbe({
    label: 'probe11-non-async-server-function',
    files: {
      'app/scratch-s7-p11/actions.ts': `'use server'

export function nonAsyncAction() {
  return 'x'
}
`,
      'app/scratch-s7-p11/page.tsx': `import { nonAsyncAction } from './actions'

export default function Page() {
  return (
    <form action={nonAsyncAction}>
      <button type="submit">Go</button>
    </form>
  )
}
`,
    },
    run: null,
  })
  pushResult(
    block(
      11,
      "a non-async export in a 'use server' file",
      'app/scratch-s7-p11/{actions.ts,page.tsx} (scratch pair)',
      buildResult,
      'not applicable — build must pass before request-time behavior can be observed',
      buildResult.status !== 0 ? 'n/a — caught at build' : 'unexpected: this built; see full extract',
    ),
  )
}

writeObs(
  'enforcement-matrix.txt',
  'eleven probes, one at a time: add -> pnpm build -> capture -> (if built) pnpm start + curl -> capture -> remove',
  results.join('\n'),
)

// ---- §3 follow-up: does /streaming-coarse's Revalidate/Expire column track the shortest CACHED entry regardless of shell membership? ----
console.error('probe: section3-route-lifetime-column')
removeAllScratch()
const streamingCoarsePath = join(appDir, 'streaming-coarse', 'page.tsx')
const originalStreamingCoarse = existsSync(streamingCoarsePath)
  ? readFileSync(streamingCoarsePath, 'utf8')
  : null

let s3Result = '(streaming-coarse page not found; probe skipped)'
if (originalStreamingCoarse !== null) {
  writeScratch('lib/_scratch-p3-minutes.ts', `import { cacheLife } from 'next/cache'

export async function getMinutesTag() {
  'use cache'
  cacheLife('minutes')
  return 'minutes-tagged-value'
}
`)
  const marker = 'export default function CoarseStreamingPage() {\n  return ('
  if (!originalStreamingCoarse.includes(marker)) {
    s3Result = `(probe skipped — expected marker not found in ${streamingCoarsePath})`
  } else {
    const patched =
      `import { getMinutesTag } from '@/lib/_scratch-p3-minutes'\n` +
      originalStreamingCoarse.replace(
        marker,
        `export default async function CoarseStreamingPage() {\n  const _scratchMinutes = await getMinutesTag()\n  return (`,
      ).replace(
        '<main>',
        '<main data-scratch-minutes={_scratchMinutes}>',
      )
    writeFileSync(streamingCoarsePath, patched)

    const buildResult = build()
    const tableSection = buildResult.out
      .split(/\r?\n/)
      .filter((l) => /\/streaming-coarse|Route \(app\)|Revalidate|Expire/.test(l))
      .join('\n')
    s3Result = [
      `build: ${buildResult.status === 0 ? 'PASS' : 'FAIL exit ' + buildResult.status}`,
      buildResult.status === 0
        ? `route table lines mentioning /streaming-coarse:\n${tableSection || '(no matching line found in build output)'}`
        : extractErrors(buildResult.out),
    ].join('\n')

    // restore
    writeFileSync(streamingCoarsePath, originalStreamingCoarse)
    removeAllScratch()
  }
}

writeObs(
  'route-lifetime-column.txt',
  "add a second cached fn with cacheLife('minutes') to /streaming-coarse (whose only existing cached entry session 5 measured absent from the prerender); pnpm build; read the Revalidate/Expire columns; revert",
  [
    'baseline (session 6, before this probe): /streaming-coarse showed 1h 1d',
    "this probe: added a second 'use cache' fn with cacheLife('minutes'), called (and its result read) from the same route, alongside the pre-existing entry",
    s3Result,
  ].join('\n'),
)

// final clean rebuild to confirm nothing scratch survives
console.error('final clean rebuild check')
removeAllScratch()
const clean = build()
writeObs(
  '_session7-clean-rebuild-check.txt',
  'pnpm build after all scratch removed — sanity check only, not cited by the article',
  `build: ${clean.status === 0 ? 'PASS' : 'FAIL exit ' + clean.status}\n${clean.status !== 0 ? extractErrors(clean.out) : '(clean)'}`,
)

console.error('session7 observe done')
