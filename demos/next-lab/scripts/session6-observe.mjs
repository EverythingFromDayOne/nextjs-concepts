/**
 * Session 6 observation pass — four experiments.
 * Unique public scratch routes per probe (NOT _private folders).
 * Do not wipe .next between builds — that races Turbopack on Windows.
 */
import {
  writeFileSync,
  mkdirSync,
  rmSync,
  existsSync,
  readdirSync,
} from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync, spawn } from 'node:child_process'
import { setTimeout as sleep } from 'node:timers/promises'

const lab = join(dirname(fileURLToPath(import.meta.url)), '..')
const obs = join(lab, 'observations')
const appDir = join(lab, 'app')
const stamped = join(lab, 'lib', '_scratch-stamped.ts')
mkdirSync(obs, { recursive: true })

const DATE = '2026-08-10'
const NEXT = 'next@16.3.0'
const PORT = 3016

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
  return {
    status: r.status ?? 1,
    out: (r.stdout || '') + (r.stderr || ''),
  }
}

function extractErrors(out) {
  const lines = out.split(/\r?\n/)
  const idxs = []
  for (let i = 0; i < lines.length; i++) {
    if (/Error:|Export encountered|⨯|ELIFECYCLE|unstable value/i.test(lines[i])) {
      idxs.push(i)
    }
  }
  if (idxs.length === 0) return out.slice(-2500)
  const chunks = []
  for (const i of idxs.slice(0, 8)) {
    chunks.push(lines.slice(Math.max(0, i - 1), i + 14).join('\n'))
  }
  return chunks.join('\n---\n')
}

function scratchPath(slug) {
  return join(appDir, slug)
}

function writeScratch(slug, pageSource) {
  const dir = scratchPath(slug)
  mkdirSync(dir, { recursive: true })
  writeFileSync(join(dir, 'page.tsx'), pageSource)
}

function listScratchDirs() {
  if (!existsSync(appDir)) return []
  return readdirSync(appDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name.startsWith('scratch-s6'))
    .map((d) => join(appDir, d.name))
}

function removeAllScratch() {
  for (let attempt = 0; attempt < 10; attempt++) {
    try {
      for (const dir of listScratchDirs()) {
        rmSync(dir, { recursive: true, force: true })
      }
      if (existsSync(stamped)) rmSync(stamped, { force: true })
      if (listScratchDirs().length === 0 && !existsSync(stamped)) return
    } catch {
      /* retry */
    }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500)
  }
  if (listScratchDirs().length || existsSync(stamped)) {
    throw new Error(
      `failed to remove scratch: ${listScratchDirs().join(', ')} stamped=${existsSync(stamped)}`,
    )
  }
}

function killPort(port) {
  spawnSync(
    'powershell',
    [
      '-NoProfile',
      '-Command',
      `Get-NetTCPConnection -LocalPort ${port} -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }`,
    ],
    { encoding: 'utf8' },
  )
}

async function startServer() {
  killPort(PORT)
  await sleep(500)
  const child = spawn('pnpm', ['exec', 'next', 'start', '--port', String(PORT)], {
    cwd: lab,
    shell: true,
    stdio: ['ignore', 'pipe', 'pipe'],
    env: process.env,
  })
  const logs = []
  await new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('boot timeout')), 90000)
    const on = (b) => {
      const s = b.toString()
      logs.push(s)
      process.stderr.write(s)
      if (/Ready|Local:/.test(s)) {
        clearTimeout(t)
        resolve()
      }
    }
    child.stdout.on('data', on)
    child.stderr.on('data', on)
    child.on('exit', (c) => {
      clearTimeout(t)
      reject(new Error(`server exit ${c}`))
    })
  })
  await sleep(400)
  return { child, logs }
}

async function stopServer(child) {
  try {
    child.kill()
  } catch {
    /* ignore */
  }
  killPort(PORT)
  await sleep(800)
}

removeAllScratch()

const primitives = [
  {
    label: 'new Date()',
    slug: 'scratch-s6-date',
    body: `export default function Page() {
  return <time>{new Date().toISOString()}</time>
}
`,
  },
  {
    label: 'Date.now()',
    slug: 'scratch-s6-now',
    body: `export default function Page() {
  return <p>{Date.now()}</p>
}
`,
  },
  {
    label: 'Math.random()',
    slug: 'scratch-s6-random',
    body: `export default function Page() {
  return <p>{Math.random()}</p>
}
`,
  },
  {
    label: 'crypto.randomUUID()',
    slug: 'scratch-s6-uuid',
    body: `export default function Page() {
  return <p>{crypto.randomUUID()}</p>
}
`,
  },
]

const exp1 = []
for (const p of primitives) {
  console.error('exp1', p.label)
  removeAllScratch()
  writeScratch(p.slug, p.body)
  await sleep(200)
  const { status, out } = build()
  const caught = status !== 0
  const err = extractErrors(out)
  const named =
    /unstable value `([^`]+)`/.exec(err)?.[1] ??
    (caught ? '(exit non-zero; name not parsed)' : '(not caught)')
  exp1.push(
    [
      `### ${p.label}`,
      `route: /${p.slug}`,
      `build exit: ${status}`,
      `caught: ${caught}`,
      `error names unstable value: ${named}`,
      err,
      '---',
    ].join('\n'),
  )
  removeAllScratch()
}
writeObs(
  'sync-io-variants.txt',
  'unique scratch routes per primitive; pnpm build each; remove scratch',
  exp1.join('\n'),
)

console.error('exp2 instant=false + new Date()')
removeAllScratch()
writeScratch(
  'scratch-s6-instant',
  `export const instant = false

export default function Page() {
  return <time>{new Date().toISOString()}</time>
}
`,
)
await sleep(200)
{
  const { status, out } = build()
  writeObs(
    'instant-false-syncio.txt',
    'scratch-s6-instant with instant=false + bare new Date(); pnpm build; remove scratch',
    [
      `build exit: ${status}`,
      `clears sync-IO error (exit 0): ${status === 0}`,
      extractErrors(out),
    ].join('\n'),
  )
}
removeAllScratch()

console.error('exp3 date in use cache')
removeAllScratch()
writeFileSync(
  stamped,
  `import { cacheLife } from 'next/cache'
import { db } from './db'

export async function getStamped() {
  'use cache'
  cacheLife('minutes')
  return { at: new Date().toISOString(), data: await db.report.summary() }
}
`,
)
writeScratch(
  'scratch-s6-cached-date',
  `import { getStamped } from '@/lib/_scratch-stamped'

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
)
await sleep(200)

const exp3Build = build()
let exp3Run = 'not run — build failed'
if (exp3Build.status === 0) {
  const { child } = await startServer()
  try {
    function curlAt() {
      const r = spawnSync(
        'curl.exe',
        ['-s', `http://localhost:${PORT}/scratch-s6-cached-date`],
        { encoding: 'utf8' },
      )
      const html = r.stdout || ''
      const m = html.match(/data-at="([^"]+)"/)
      return {
        at: m?.[1] ?? null,
        len: html.length,
        snippet: html.match(/<main[\s\S]{0,200}/)?.[0],
      }
    }

    const first = curlAt()
    await sleep(2500)
    const second = curlAt()
    exp3Run = [
      `request1 at: ${first.at} (len=${first.len})`,
      `request2 at (2.5s later): ${second.at} (len=${second.len})`,
      `same timestamp (frozen at entry creation): ${first.at !== null && first.at === second.at}`,
      `snippet1: ${first.snippet}`,
    ].join('\n')
  } finally {
    await stopServer(child)
  }
}

writeObs(
  'date-in-cache-scope.txt',
  "scratch-s6-cached-date getStamped() with new Date() inside 'use cache'; build; two curls 2.5s apart; remove scratch",
  [
    `builds: ${exp3Build.status === 0}`,
    `build exit: ${exp3Build.status}`,
    extractErrors(exp3Build.out),
    '---',
    `runs: ${exp3Build.status === 0}`,
    exp3Run,
  ].join('\n'),
)
removeAllScratch()

console.error('exp4 after-demo clean rebuild')
await sleep(300)
const clean = build()
if (clean.status !== 0) {
  console.error(clean.out.slice(-3500))
  removeAllScratch()
  throw new Error('clean build failed')
}

const { child, logs } = await startServer()
try {
  const curl = spawnSync(
    'curl.exe',
    [
      '-s',
      '-w',
      '\n%{time_total} response complete\n',
      `http://localhost:${PORT}/after-demo`,
    ],
    { encoding: 'utf8' },
  )
  await sleep(1200)

  const logText = logs.join('')
  const interesting = logText
    .split(/\r?\n/)
    .filter((l) => /\[render\]|\[audit\]/.test(l))
    .join('\n')
  const timeMatch = (curl.stdout || '').match(/([\d.]+) response complete/)
  const timeTotal = timeMatch ? Number(timeMatch[1]) : null

  writeObs(
    'after-ordering.txt',
    `next start --port ${PORT}; curl -w time_total http://localhost:${PORT}/after-demo`,
    [
      '--- curl ---',
      (curl.stdout || '').slice(0, 800),
      '--- server log lines of interest ---',
      interesting || '(no [render]/[audit] lines — may be buffered differently)',
      '--- claim ---',
      `time_total_s: ${timeTotal}`,
      `visitor time_total << 0.300s: ${timeTotal !== null && timeTotal < 0.3}`,
      'visitor time_total should be << 300ms audit delay if after() is post-response',
    ].join('\n'),
  )
} finally {
  await stopServer(child)
}

removeAllScratch()
console.error('session6 observe done')
