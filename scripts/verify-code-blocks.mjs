#!/usr/bin/env node
/**
 * verify-code-blocks.mjs — CI gate 1.
 *
 * Every fenced code block in docs/ that carries a provenance comment must
 * still match the demo source it was extracted from, byte for byte.
 *
 *   <!-- extract: demos/next-lab/lib/billing.ts#getPlans -->
 *   ```ts
 *   export async function getPlans() {
 *     ...
 *   }
 *   ```
 *
 * Blocks without a provenance comment are counted as unsourced and reported,
 * but do not fail the build by default — an article in `draft` is allowed to
 * carry authored blocks. Pass --strict to fail on them; the CI job runs
 * --strict only for articles whose frontmatter status is not `draft`.
 *
 * Exception under --strict: unsourced fences tagged `bash`, `sh`, or `shell`
 * are allowed — shell commands have no demo source (see session-4 article 6).
 *
 * usage:
 *   node scripts/verify-code-blocks.mjs [--docs docs] [--strict]
 * exit:
 *   0 all sourced blocks match
 *   1 any mismatch, unreadable source, or (with --strict) unsourced block
 */

import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { extract, ExtractError } from './lib/extract.mjs'

const args = process.argv.slice(2)
const docsDir = valueOf('--docs') ?? 'docs'
const strict = args.includes('--strict')
const root = process.cwd()

function valueOf(flag) {
  const i = args.indexOf(flag)
  return i === -1 ? undefined : args[i + 1]
}

function walk(dir, out = []) {
  for (const entry of readdirSync(dir)) {
    if (entry === 'node_modules' || entry.startsWith('.')) continue
    const full = join(dir, entry)
    if (statSync(full).isDirectory()) walk(full, out)
    else if (entry.endsWith('.md')) out.push(full)
  }
  return out
}

const EXTRACT_RE = /^<!--\s*extract:\s*(.+?)\s*-->$/
const FENCE_RE = /^```/

function frontmatterStatus(text) {
  const cleaned = text.replace(/^\uFEFF/, '')
  const m = /^---\r?\n([\s\S]*?)\r?\n---/.exec(cleaned)
  if (!m) return undefined
  const s = /^status:\s*(\S+)/m.exec(m[1])
  return s?.[1]
}

/** Normalise for comparison: strip trailing whitespace per line and at EOF. */
function norm(s) {
  return s.split('\n').map((l) => l.replace(/\s+$/, '')).join('\n').replace(/\n+$/, '')
}

let checked = 0
let unsourced = 0
let unsourcedShell = 0
const failures = []

let files
try {
  files = walk(join(root, docsDir))
} catch {
  console.error(`verify-code-blocks: cannot read ${docsDir}/`)
  process.exit(1)
}

for (const file of files) {
  const rel = relative(root, file)
  const text = readFileSync(file, 'utf8')
  const lines = text.split('\n')
  const status = frontmatterStatus(text)
  const strictHere = strict && status !== undefined && status !== 'draft'

  for (let i = 0; i < lines.length; i++) {
    if (!FENCE_RE.test(lines[i])) continue

    // Find the end of this fence.
    let end = i + 1
    while (end < lines.length && !FENCE_RE.test(lines[end])) end++
    if (end >= lines.length) {
      failures.push(`${rel}:${i + 1} — unterminated code fence`)
      break
    }

    const fenceOpen = lines[i].match(/^```(\w*)/)
    const fenceLang = (fenceOpen?.[1] ?? '').toLowerCase()
    const body = lines.slice(i + 1, end).join('\n')

    // Provenance comment sits on the line immediately above the fence,
    // allowing one blank line between.
    let p = i - 1
    if (p >= 0 && lines[p].trim() === '') p--
    const prov = p >= 0 ? EXTRACT_RE.exec(lines[p].trim()) : null

    if (!prov) {
      unsourced++
      const shellOk = fenceLang === 'bash' || fenceLang === 'sh' || fenceLang === 'shell'
      if (shellOk) unsourcedShell++
      if (strictHere && !shellOk) {
        failures.push(
          `${rel}:${i + 1} — unsourced code block in a non-draft article ` +
          `(add "<!-- extract: <path>#<symbol> -->" or move the code into demos/)`
        )
      }
      i = end
      continue
    }

    const spec = prov[1]
    checked++
    try {
      const expected = extract(spec, root)
      if (norm(expected) !== norm(body)) {
        failures.push(
          `${rel}:${i + 1} — block does not match ${spec}\n` +
          `        rebuild with: python3 scripts/build-article.py ${rel.replace(/\.md$/, '.md.tpl')}`
        )
      }
    } catch (err) {
      const msg = err instanceof ExtractError ? err.message : String(err)
      failures.push(`${rel}:${p + 1} — extract failed for ${spec}: ${msg}`)
    }

    i = end
  }
}

for (const f of failures) console.error(`verify-code-blocks: ${f}`)

console.log(
  `verify-code-blocks: ${checked} sourced / ${unsourcedShell} unsourced-shell / ` +
  `${unsourced - unsourcedShell} unsourced-other across ${files.length} file(s); ` +
  `${failures.length} failure(s)`
)

process.exit(failures.length ? 1 : 0)
