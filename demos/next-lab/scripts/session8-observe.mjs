/**
 * Session 8 observation pass — article 2 rewrite (`server-and-client-components`).
 *
 * Experiment A: payload cost across the boundary. Four scratch routes
 * (payload-a-40, payload-a-4000, payload-b-40, payload-b-4000), each
 * rendering the same visible output, differing only in whether the product
 * array crosses the client boundary as a prop (a-shape) or stays server-side
 * and crosses only as rendered `children` (b-shape).
 *
 * Experiment B: the silent Server Component conversion. Two scratch routes
 * (convert-a, convert-b) — same output, one composes ProductRow as children,
 * the other imports it directly into a client file. Bundle rows compared,
 * then `import 'server-only'` added to product-row.tsx and rebuilt.
 *
 * All routes and the server-only edit are scratch — removed by the caller
 * after this script runs. This script only builds, starts/stops the
 * production server, and curls/reads build artifacts.
 */
import { writeFileSync, mkdirSync, readFileSync, existsSync, statSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync, spawn } from 'node:child_process'
import net from 'node:net'
import { setTimeout as sleep } from 'node:timers/promises'

const lab = join(dirname(fileURLToPath(import.meta.url)), '..')
const obs = join(lab, 'observations')
mkdirSync(obs, { recursive: true })

const DATE = '2026-08-14'
const NEXT = 'next@16.3.0'
const PORT = 3021

// eslint-disable-next-line no-control-regex
const ANSI = /\x1b\[[0-9;]*m/g
function stripAnsi(s) {
  return s.replace(ANSI, '')
}

function writeObs(name, command, body) {
  writeFileSync(
    join(obs, name),
    stripAnsi(`# produced: ${DATE}; ${NEXT}; command: ${command}\n${body.trimEnd()}\n`),
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

function curlBytes(path, extraArgs = []) {
  const r = spawnSync(
    'curl',
    ['-s', '-o', '/dev/null', '-w', '%{size_download} %{http_code}', ...extraArgs, `http://localhost:${PORT}${path}`],
    { encoding: 'utf8' },
  )
  const [size, code] = (r.stdout || '0 0').trim().split(/\s+/)
  return { bytes: Number(size), status: Number(code) }
}

function buildTableFor(out, routes) {
  return out
    .split(/\r?\n/)
    .filter((l) => /Route \(app\)/.test(l) || routes.some((r) => l.includes(r)))
}

function entryJsBytesFor(routeDir, pageProjectPath) {
  const manifest = join(lab, '.next/server/app', routeDir, 'page_client-reference-manifest.js')
  if (!existsSync(manifest)) return { bytes: 0, files: [], found: false }
  const text = readFileSync(manifest, 'utf8')
  const marker = '"entryJSFiles"'
  const entryIdx = text.indexOf(marker)
  if (entryIdx < 0) return { bytes: 0, files: [], found: false }
  const pageKey = `"[project]/demos/next-lab/${pageProjectPath}"`
  const idx = text.indexOf(pageKey, entryIdx)
  if (idx < 0) return { bytes: 0, files: [], found: false }
  const after = text.slice(idx + pageKey.length)
  const arrMatch = after.match(/^\s*:\s*\[([^\]]*)\]/)
  if (!arrMatch) return { bytes: 0, files: [], found: false }
  const files = [...arrMatch[1].matchAll(/"([^"]+)"/g)].map((m) => m[1])
  let bytes = 0
  for (const f of files) {
    const abs = join(lab, '.next', f)
    if (existsSync(abs)) bytes += statSync(abs).size
  }
  return { bytes, files, found: true }
}

function clientOwnedModules(routeDir, pathFragment) {
  const manifest = join(lab, '.next/server/app', routeDir, 'page_client-reference-manifest.js')
  if (!existsSync(manifest)) return []
  const text = readFileSync(manifest, 'utf8')
  const cm = text.match(/"clientModules":\{([\s\S]*?)\},"ssrModuleMapping"/)
  if (!cm) return []
  const owned = []
  for (const m of cm[1].matchAll(
    /"(\[project\]\/demos\/next-lab\/[^"]+)":\{[^}]*"chunks":\[([^\]]*)\]/g,
  )) {
    if (m[1].includes(pathFragment)) owned.push(m[1])
  }
  return owned
}

killPort(PORT)

const mode = process.argv[2]

if (mode === 'payload') {
  // ---- Experiment A: payload cost across the boundary ----
  console.error('experiment A: build')
  const buildResult = build()
  if (buildResult.status !== 0) {
    writeObs('_session8-payload-build-failed.txt', 'pnpm build', buildResult.out)
    console.error('BUILD FAILED — see observations/_session8-payload-build-failed.txt')
    process.exit(1)
  }

  const routes = ['payload-a-40', 'payload-a-4000', 'payload-b-40', 'payload-b-4000']
  const tableLines = buildTableFor(buildResult.out, routes)

  const bundle = {}
  for (const r of routes) {
    bundle[r] = entryJsBytesFor(r, `app/${r}/page`)
  }

  console.error('experiment A: start + curl (full HTML)')
  const { child } = await startServer()
  const html = {}
  try {
    for (const r of routes) {
      html[r] = curlBytes(`/${r}`)
    }
  } finally {
    await stopServer(child)
  }

  // Attempt to separate the RSC payload from the HTML. Per the bundled docs
  // (cdn-caching.md), the `rsc: 1` request header asks the server for a
  // flight payload instead of HTML — but `experimental.validateRSCRequestHeaders`
  // is on by default and 307s a raw `rsc: 1` request that lacks the client's
  // computed `_rsc` hash. Rebuilding once with that flag off (scratch-only;
  // reverted by the caller) makes the header sufficient on its own, which is
  // real separation, not an estimate.
  console.error('experiment A: rebuild with validateRSCRequestHeaders off, re-measure RSC-only')
  const configPath = join(lab, 'next.config.ts')
  const originalConfig = readFileSync(configPath, 'utf8')
  writeFileSync(
    configPath,
    originalConfig.replace(
      'partialPrefetching: true,',
      'partialPrefetching: true,\n  experimental: { validateRSCRequestHeaders: false },',
    ),
  )
  const buildNoValidate = build()
  let rsc = {}
  let rscNote
  if (buildNoValidate.status !== 0) {
    rscNote = 'rebuild with validateRSCRequestHeaders:false FAILED — RSC payload not separated; reporting HTML-only totals above.'
  } else {
    const { child: child2 } = await startServer()
    try {
      for (const r of routes) {
        rsc[r] = curlBytes(`/${r}`, ['-H', 'rsc: 1'])
      }
    } finally {
      await stopServer(child2)
    }
    rscNote = null
  }
  writeFileSync(configPath, originalConfig)
  // restore .next to match the checked-in config
  build()

  const lines = []
  lines.push('## Build table — the four payload routes (from the same `pnpm build` used below)')
  lines.push(tableLines.join('\n') || '(no matching lines captured)')
  lines.push('')
  lines.push('## Bundle size — entryJSFiles from page_client-reference-manifest.js (route-owned JS only)')
  for (const r of routes) {
    lines.push(`${r.padEnd(16)} entryJSFiles = ${bundle[r].bytes} B  (${bundle[r].files.join(', ') || 'none found'})`)
  }
  lines.push('')
  lines.push('## Total HTML response size — curl -s -o /dev/null -w "%{size_download} %{http_code}" (production server, no rsc header)')
  for (const r of routes) {
    lines.push(`${r.padEnd(16)} ${html[r].bytes} B  (HTTP ${html[r].status})`)
  }
  lines.push('')
  if (rscNote) {
    lines.push(`## RSC payload separated from HTML: ${rscNote}`)
  } else {
    lines.push('## RSC payload only — curl -H "rsc: 1" against a build with experimental.validateRSCRequestHeaders:false (scratch config, reverted)')
    lines.push('This isolates exactly what crosses the boundary for hydration: the a-shape ships the raw product objects (id, slug, name, description, priceCents) as props; the b-shape ships only the already-rendered `<li>` elements ProductRow produced (name + formatted price, nothing else).')
    for (const r of routes) {
      lines.push(`${r.padEnd(16)} ${rsc[r].bytes} B  (HTTP ${rsc[r].status})`)
    }
    lines.push('')
    const ratio4000 = (rsc['payload-a-4000'].bytes / rsc['payload-b-4000'].bytes).toFixed(2)
    const ratio40 = (rsc['payload-a-40'].bytes / rsc['payload-b-40'].bytes).toFixed(2)
    const perItem4000 = ((rsc['payload-a-4000'].bytes - rsc['payload-b-4000'].bytes) / 4000).toFixed(1)
    const perItem40 = ((rsc['payload-a-40'].bytes - rsc['payload-b-40'].bytes) / 40).toFixed(1)
    lines.push(`a/b ratio at 40 products: ${ratio40}x (${(rsc['payload-a-40'].bytes - rsc['payload-b-40'].bytes)} B difference, ${perItem40} B/product)`)
    lines.push(`a/b ratio at 4,000 products: ${ratio4000}x (${(rsc['payload-a-4000'].bytes - rsc['payload-b-4000'].bytes)} B difference, ${perItem4000} B/product)`)
  }

  writeObs(
    'payload-boundary.txt',
    'pnpm build; pnpm start; curl -s -o /dev/null -w "%{size_download} %{http_code}" /payload-{a,b}-{40,4000} (twice: HTML, then RSC-only with validateRSCRequestHeaders off)',
    lines.join('\n'),
  )
}

if (mode === 'convert') {
  // ---- Experiment B: the silent Server Component conversion ----
  console.error('experiment B: build (before server-only)')
  const buildBefore = build()
  if (buildBefore.status !== 0) {
    writeObs('_session8-convert-build-failed.txt', 'pnpm build (before server-only)', buildBefore.out)
    console.error('BUILD FAILED before server-only — see observations/_session8-convert-build-failed.txt')
    process.exit(1)
  }
  const tableBefore = buildTableFor(buildBefore.out, ['convert-a', 'convert-b'])
  const bundleABefore = entryJsBytesFor('convert-a', 'app/convert-a/page')
  const bundleBBefore = entryJsBytesFor('convert-b', 'app/convert-b/page')
  const productRowOwnedBefore = clientOwnedModules('convert-b', 'product-row')

  console.error('experiment B: add server-only, build again')
  const productRowPath = join(lab, 'app/catalog/product-row.tsx')
  const original = readFileSync(productRowPath, 'utf8')
  writeFileSync(productRowPath, `import 'server-only'\n\n${original}`)

  const buildAfter = build()
  const tableAfter = buildTableFor(buildAfter.out, ['convert-a', 'convert-b'])

  // restore immediately, regardless of outcome
  writeFileSync(productRowPath, original)

  const lines = []
  lines.push('## Step 1 — before `server-only`: build both routes, compare bundle rows')
  lines.push(tableBefore.join('\n') || '(no matching lines captured)')
  lines.push('')
  lines.push(`convert-a entryJSFiles = ${bundleABefore.bytes} B  (${bundleABefore.files.join(', ') || 'none found'})`)
  lines.push(`convert-b entryJSFiles = ${bundleBBefore.bytes} B  (${bundleBBefore.files.join(', ') || 'none found'})`)
  lines.push('')
  lines.push('`ProductRow` as its own entry in convert-b\'s client-reference manifest (clientModules matching "product-row"):')
  lines.push(productRowOwnedBefore.length ? productRowOwnedBefore.join('\n') : '(none — not a separate module; see whether it is inlined into the importing file below)')
  lines.push('')
  lines.push('## Step 2 — after `import \'server-only\'` in product-row.tsx, rebuild')
  lines.push(`build exit code: ${buildAfter.status}`)
  if (buildAfter.status !== 0) {
    const errLines = buildAfter.out.split(/\r?\n/)
    const idxs = []
    for (let i = 0; i < errLines.length; i++) {
      if (/Error:|Failed to compile|×|⨯|server-only/i.test(errLines[i])) idxs.push(i)
    }
    const snippet = idxs.length
      ? idxs.slice(0, 3).map((i) => errLines.slice(Math.max(0, i - 1), i + 8).join('\n')).join('\n---\n')
      : buildAfter.out.slice(-2000)
    lines.push('build FAILED. Relevant output:')
    lines.push(snippet)
  } else {
    lines.push('build PASSED. Route table for convert-a / convert-b:')
    lines.push(tableAfter.join('\n') || '(no matching lines captured)')
  }

  writeObs(
    'silent-conversion.txt',
    "pnpm build (convert-a vs convert-b); add import 'server-only' to product-row.tsx; pnpm build again",
    lines.join('\n'),
  )

  // final rebuild to leave .next in a clean state matching the restored source
  console.error('experiment B: final rebuild after restoring product-row.tsx')
  build()
}

console.error('session8 observe done:', mode)
