/**
 * Session 5 observation pass — one shot.
 * Writes the six observation files under observations/.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync, spawn } from 'node:child_process'
import { setTimeout as sleep } from 'node:timers/promises'

const lab = join(dirname(fileURLToPath(import.meta.url)), '..')
const obs = join(lab, 'observations')
mkdirSync(obs, { recursive: true })

const PORT = 3015
const DATE = '2026-08-10'
const NEXT = 'next@16.3.0'

function writeObs(name, command, body) {
  const text = `# produced: ${DATE}; ${NEXT}; command: ${command}\n${body.trimEnd()}\n`
  writeFileSync(join(obs, name), text)
  console.error('wrote', name)
}

function build() {
  const r = spawnSync('pnpm', ['build'], {
    cwd: lab,
    encoding: 'utf8',
    shell: true,
    env: process.env,
  })
  if (r.status !== 0) {
    console.error(r.stdout)
    console.error(r.stderr)
    throw new Error(`build failed: ${r.status}`)
  }
  return r.stdout + (r.stderr ?? '')
}

function trimMain(html) {
  const m = html.match(/<main[\s\S]*?<\/main>/i)
  return m ? m[0] : '(no <main> found)\n' + html.slice(0, 500)
}

function summarizeShell(fine, coarse) {
  const has = (html, re) => re.test(html)
  const lines = [
    'fine shell has Weekly report header: ' + has(fine, /Weekly report/),
    'fine shell has 2026-W32: ' + has(fine, /2026-W32/),
    'fine shell has Revenue skeleton: ' + has(fine, /Revenue/),
    'fine shell has Traffic skeleton: ' + has(fine, /Traffic/),
    'fine shell has Errors skeleton: ' + has(fine, /Errors/),
    'fine shell has aria-busy: ' + has(fine, /aria-busy/),
    'coarse shell has Weekly report header (summary): ' + has(coarse, /Weekly report —/),
    'coarse shell has 2026-W32: ' + has(coarse, /2026-W32/),
    'coarse shell has skeleton title Weekly report: ' + has(coarse, />Weekly report</),
    'coarse shell has Revenue: ' + has(coarse, /Revenue/),
    'coarse shell has Traffic: ' + has(coarse, /Traffic/),
    'coarse shell has Errors: ' + has(coarse, /Errors/),
    'coarse shell has aria-busy: ' + has(coarse, /aria-busy/),
  ]
  return lines.join('\n')
}

console.error('building…')
const buildOut = build()

const tableLines = buildOut
  .split(/\r?\n/)
  .filter((l) =>
    /Route \(app\)|streaming|Revalidate|Expire|Static|Partial|Dynamic|○|◐|ƒ/.test(l),
  )
  .join('\n')

writeObs(
  'streaming-build-table.txt',
  'pnpm build (filter next-lab)',
  tableLines || buildOut.slice(-2000),
)

const finePath = join(lab, '.next/server/app/streaming.html')
const coarsePath = join(lab, '.next/server/app/streaming-coarse.html')
if (!existsSync(finePath) || !existsSync(coarsePath)) {
  throw new Error(`missing shell files: fine=${existsSync(finePath)} coarse=${existsSync(coarsePath)}`)
}

const fineHtml = readFileSync(finePath, 'utf8')
const coarseHtml = readFileSync(coarsePath, 'utf8')
const fineMain = trimMain(fineHtml)
const coarseMain = trimMain(coarseHtml)

writeObs(
  'streaming-fine-shell.html.txt',
  'read .next/server/app/streaming.html; trim to <main>…</main>',
  fineMain,
)
writeObs(
  'streaming-coarse-shell.html.txt',
  'read .next/server/app/streaming-coarse.html; trim to <main>…</main>',
  coarseMain,
)
writeObs(
  'streaming-shell-diff.txt',
  'compare streaming.html vs streaming-coarse.html <main> contents',
  summarizeShell(fineMain, coarseMain),
)

console.error('starting server on', PORT)
const child = spawn('pnpm', ['exec', 'next', 'start', '--port', String(PORT)], {
  cwd: lab,
  shell: true,
  stdio: ['ignore', 'pipe', 'pipe'],
  env: process.env,
})

let ready = false
const boot = new Promise((resolve, reject) => {
  const t = setTimeout(() => reject(new Error('server boot timeout')), 60000)
  const onData = (buf) => {
    const s = buf.toString()
    process.stderr.write(s)
    if (/Ready|started server|Local:/.test(s)) {
      ready = true
      clearTimeout(t)
      resolve()
    }
  }
  child.stdout.on('data', onData)
  child.stderr.on('data', onData)
  child.on('exit', (code) => {
    if (!ready) {
      clearTimeout(t)
      reject(new Error(`server exited early: ${code}`))
    }
  })
})

try {
  await boot
  await sleep(500)

  function curlRoute(path) {
    const r = spawnSync(
      'curl.exe',
      [
        '-N',
        '--raw',
        '-s',
        '-w',
        '\n%{time_starttransfer} first byte\n%{time_total} total\n',
        `http://localhost:${PORT}${path}`,
      ],
      { encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 },
    )
    return (r.stdout || '') + (r.stderr || '')
  }

  const fineCurl = curlRoute('/streaming')
  // Annotate arrival markers for readability
  const markers = []
  if (/Subscriptions|Revenue/.test(fineCurl)) markers.push('saw Revenue content')
  if (/Sessions|Traffic/.test(fineCurl)) markers.push('saw Traffic content')
  if (/5xx|Errors/.test(fineCurl)) markers.push('saw Errors content')
  if (/2026-W32/.test(fineCurl)) markers.push('saw Summary week')

  writeObs(
    'streaming-chunk-order.txt',
    `curl -N --raw -w timings http://localhost:${PORT}/streaming`,
    [
      'markers: ' + markers.join('; '),
      'note: with -N the body is one buffer here; timings still show TTFB vs total gap from streaming wait',
      fineCurl.slice(0, 4000),
      fineCurl.length > 4000 ? `\n… truncated (${fineCurl.length} chars) …\n` + fineCurl.slice(-800) : '',
    ].join('\n'),
  )

  const coarseCurl = curlRoute('/streaming-coarse')
  writeObs(
    'streaming-coarse-timing.txt',
    `curl -N --raw -w timings http://localhost:${PORT}/streaming-coarse`,
    [
      'note: total should approach ~1.5s (slowest panel); TTFB may still be early if shell/fallback flushes first',
      coarseCurl.slice(0, 2000),
      coarseCurl.length > 2000 ? `\n… truncated …\n` + coarseCurl.slice(-600) : '',
    ].join('\n'),
  )
} finally {
  child.kill()
}

console.error('done')
console.error('--- prediction evidence ---')
console.error(summarizeShell(fineMain, coarseMain))
