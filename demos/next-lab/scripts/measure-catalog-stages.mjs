/**
 * Temporarily mount each catalog stage as app/catalog/page.tsx, build,
 * and sum entryJSFiles from the route's client-reference manifest.
 * Restores the original page.tsx on exit.
 */
import {
  copyFileSync,
  readFileSync,
  writeFileSync,
  existsSync,
  statSync,
  unlinkSync,
} from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const pagePath = join(root, 'app/catalog/page.tsx')
const backupPath = join(root, 'app/catalog/page.tsx.__measure_backup')

const stages = {
  1: `import { Stage1CatalogPage } from './_stages/stage1-page'
export default Stage1CatalogPage
`,
  2: `import { Stage2CatalogPage } from './_stages/stage2-page'
export default Stage2CatalogPage
`,
  3: `import { Stage3CatalogPage } from './_stages/stage3-page'
export default Stage3CatalogPage
`,
}

function sumEntryJs(stage) {
  const manifest = join(
    root,
    '.next/server/app/catalog/page_client-reference-manifest.js',
  )
  const text = readFileSync(manifest, 'utf8')
  const marker = '"entryJSFiles"'
  const entryIdx = text.indexOf(marker)
  if (entryIdx < 0) throw new Error(`entryJSFiles missing (stage ${stage})`)
  const pageKey = '"[project]/demos/next-lab/app/catalog/page"'
  const idx = text.indexOf(pageKey, entryIdx)
  if (idx < 0) throw new Error(`catalog page key missing (stage ${stage})`)
  const after = text.slice(idx + pageKey.length)
  const arrMatch = after.match(/^\s*:\s*\[([^\]]*)\]/)
  if (!arrMatch) throw new Error(`entryJSFiles array missing (stage ${stage})`)
  const files = [...arrMatch[1].matchAll(/"([^"]+)"/g)].map((m) => m[1])
  let bytes = 0
  const detail = []
  for (const f of files) {
    const abs = join(root, '.next', f)
    const n = existsSync(abs) ? statSync(abs).size : 0
    bytes += n
    detail.push({ file: f, bytes: n })
  }
  // Also report route-owned client modules (exclude next/dist framework entries)
  const clientOwned = []
  const cm = text.match(/"clientModules":\{([\s\S]*?)\},"ssrModuleMapping"/)
  if (cm) {
    for (const m of cm[1].matchAll(
      /"(\[project\]\/demos\/next-lab\/[^"]+)":\{[^}]*"chunks":\[([^\]]*)\]/g,
    )) {
      const chunks = [...m[2].matchAll(/"([^"]+)"/g)].map((x) =>
        x[1].replace(/^\/_next\//, ''),
      )
      let cbytes = 0
      for (const c of chunks) {
        const abs = join(root, '.next', c)
        if (existsSync(abs)) cbytes += statSync(abs).size
      }
      clientOwned.push({ module: m[1], chunks, bytes: cbytes })
    }
  }
  return { bytes, files: detail, clientOwned }
}

function build() {
  const r = spawnSync('pnpm', ['build'], {
    cwd: root,
    encoding: 'utf8',
    shell: true,
    env: process.env,
  })
  if (r.status !== 0) {
    console.error(r.stdout)
    console.error(r.stderr)
    throw new Error(`build failed status=${r.status}`)
  }
}

copyFileSync(pagePath, backupPath)
const results = {}
try {
  for (const [stage, source] of Object.entries(stages)) {
    writeFileSync(pagePath, source)
    console.error(`building stage ${stage}…`)
    build()
    results[stage] = sumEntryJs(stage)
    console.error(`stage ${stage}: entryJS ${results[stage].bytes} bytes`)
    console.error(JSON.stringify(results[stage], null, 2))
  }
} finally {
  copyFileSync(backupPath, pagePath)
  try {
    unlinkSync(backupPath)
  } catch {
    /* ignore */
  }
  console.error('restoring stage 4 page + rebuild…')
  build()
}

console.log(JSON.stringify(results, null, 2))
