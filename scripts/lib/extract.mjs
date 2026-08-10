/**
 * extract.mjs — the single source of truth for pulling verbatim code out of
 * demo sources.
 *
 * Both `verify-code-blocks.mjs` (JS) and `build-article.py` (Python) use this
 * one implementation, so the extraction rules cannot drift between the builder
 * and the verifier. Python shells out; JS imports.
 *
 * Spec grammar
 *   <path>                    whole file
 *   <path>#<symbol>           brace-matched region + the import statements
 *                             that region actually uses (source order)
 *   <path>#<symbol>-imports   same region, deliberately without imports
 *   <path>#L<start>-L<end>    inclusive 1-based line range
 *
 * CLI
 *   node scripts/lib/extract.mjs "demos/next-lab/lib/billing.ts#getPlans"
 *   → prints the extracted region to stdout; exit 1 with a message on failure.
 */

import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export class ExtractError extends Error {}

/* ------------------------------------------------------------------ *
 * Brace matcher
 *
 * Scans forward from an offset, tracking depth of {} while ignoring braces
 * that appear inside strings, template literals, and comments.
 *
 * Known limitation, stated rather than hidden: regex literals are not
 * tokenised. A regex containing an unbalanced brace — /[{]/ — will miscount.
 * This is accepted because demo sources are ours and the failure is loud
 * (the extracted region will obviously be wrong, and the verifier will
 * report a mismatch) rather than silent. The same preference applies to
 * import-use scanning: an identifier inside a regex counts as a use
 * (false positive / noisier), not a miss.
 * ------------------------------------------------------------------ */

const NORMAL = 0
const LINE_COMMENT = 1
const BLOCK_COMMENT = 2
const SQ = 3
const DQ = 4
const TEMPLATE = 5

function matchBraces(src, startOffset) {
  let i = startOffset
  let state = NORMAL
  let depth = 0
  let opened = false
  const templateStack = []

  while (i < src.length) {
    const c = src[i]
    const next = src[i + 1]

    switch (state) {
      case NORMAL:
        if (c === '/' && next === '/') { state = LINE_COMMENT; i += 2; continue }
        if (c === '/' && next === '*') { state = BLOCK_COMMENT; i += 2; continue }
        if (c === "'") { state = SQ; i++; continue }
        if (c === '"') { state = DQ; i++; continue }
        if (c === '`') { state = TEMPLATE; i++; continue }
        if (c === '{') { depth++; opened = true; i++; continue }
        if (c === '}') {
          depth--
          if (templateStack.length && depth === templateStack[templateStack.length - 1]) {
            templateStack.pop()
            state = TEMPLATE
            i++
            continue
          }
          if (opened && depth === 0) return i + 1
          i++
          continue
        }
        i++
        continue

      case LINE_COMMENT:
        if (c === '\n') state = NORMAL
        i++
        continue

      case BLOCK_COMMENT:
        if (c === '*' && next === '/') { state = NORMAL; i += 2; continue }
        i++
        continue

      case SQ:
      case DQ: {
        const quote = state === SQ ? "'" : '"'
        if (c === '\\') { i += 2; continue }
        if (c === quote) { state = NORMAL; i++; continue }
        i++
        continue
      }

      case TEMPLATE:
        if (c === '\\') { i += 2; continue }
        if (c === '`') { state = NORMAL; i++; continue }
        if (c === '$' && next === '{') {
          templateStack.push(depth)
          depth++
          state = NORMAL
          i += 2
          continue
        }
        i++
        continue
    }
  }

  throw new ExtractError('unbalanced braces: reached end of file before closing the block')
}

function findSymbolStart(src, symbol) {
  const patterns = [
    `export\\s+default\\s+async\\s+function\\s+${symbol}\\b`,
    `export\\s+default\\s+function\\s+${symbol}\\b`,
    `export\\s+async\\s+function\\s+${symbol}\\b`,
    `export\\s+function\\s+${symbol}\\b`,
    `async\\s+function\\s+${symbol}\\b`,
    `\\bfunction\\s+${symbol}\\b`,
    `export\\s+(?:const|let|class)\\s+${symbol}\\b`,
    `\\b(?:const|let|class)\\s+${symbol}\\b`,
  ]

  for (const p of patterns) {
    const m = new RegExp(p).exec(src)
    if (m) return m.index
  }
  throw new ExtractError(`symbol not found: ${symbol}`)
}

function includeLeadingComments(src, start) {
  const lines = src.slice(0, start).split('\n')
  let take = lines.length - 1
  let i = take - 1
  while (i >= 0) {
    const t = lines[i].trim()
    if (t === '') break
    if (t.startsWith('//') || t.startsWith('*') || t.startsWith('/*') || t.startsWith('@')) {
      take = i
      i--
      continue
    }
    break
  }
  return lines.slice(0, take).join('\n').length + (take > 0 ? 1 : 0)
}

function skipWsAndComments(src, i) {
  while (i < src.length) {
    const c = src[i]
    const next = src[i + 1]
    if (c === ' ' || c === '\t' || c === '\n' || c === '\r') { i++; continue }
    if (c === '/' && next === '/') {
      i += 2
      while (i < src.length && src[i] !== '\n') i++
      continue
    }
    if (c === '/' && next === '*') {
      i += 2
      while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) i++
      i = Math.min(i + 2, src.length)
      continue
    }
    break
  }
  return i
}

/**
 * Parse one import clause into local binding names.
 * `cacheLife as cl` → `cl`; `* as ns` → `ns`; default `Foo` → `Foo`.
 */
function bindNamesFromClause(clause) {
  const names = []
  const trimmed = clause.trim()
  if (!trimmed) return names

  const ns = /^\*\s+as\s+([A-Za-z_$][\w$]*)$/.exec(trimmed)
  if (ns) return [ns[1]]

  let rest = trimmed
  if (!trimmed.startsWith('{') && !trimmed.startsWith('*')) {
    const defAndRest = /^([A-Za-z_$][\w$]*)\s*(?:,\s*(.*))?$/.exec(trimmed)
    if (defAndRest) {
      names.push(defAndRest[1])
      rest = (defAndRest[2] ?? '').trim()
      if (!rest) return names
    }
  }

  const brace = /^\{([\s\S]*)\}$/.exec(rest)
  if (brace) {
    for (const part of brace[1].split(',')) {
      const p = part.trim()
      if (!p) continue
      const asLocal = /^(?:type\s+)?(?:[A-Za-z_$][\w$]*)\s+as\s+([A-Za-z_$][\w$]*)$/.exec(p)
      if (asLocal) {
        names.push(asLocal[1])
        continue
      }
      const plain = /^(?:type\s+)?([A-Za-z_$][\w$]*)$/.exec(p)
      if (plain) names.push(plain[1])
    }
  }

  return names
}

/**
 * Contiguous leading import statements. Stops at the first non-import
 * declaration. Inter-import blanks and comments are allowed.
 */
export function parseLeadingImports(src) {
  const out = []
  let i = skipWsAndComments(src, 0)

  while (i < src.length) {
    if (!src.startsWith('import', i) || /\w/.test(src[i + 6] ?? '')) break

    const start = i
    i += 6
    let state = NORMAL
    let braceDepth = 0
    while (i < src.length) {
      const c = src[i]
      const next = src[i + 1]
      if (state === NORMAL) {
        if (c === '/' && next === '/') { state = LINE_COMMENT; i += 2; continue }
        if (c === '/' && next === '*') { state = BLOCK_COMMENT; i += 2; continue }
        if (c === "'") { state = SQ; i++; continue }
        if (c === '"') { state = DQ; i++; continue }
        if (c === '`') { state = TEMPLATE; i++; continue }
        if (c === '{') { braceDepth++; i++; continue }
        if (c === '}') { braceDepth--; i++; continue }
        if (c === ';' && braceDepth === 0) { i++; break }
        if (c === '\n' && braceDepth === 0) {
          const soFar = src.slice(start, i)
          if (/\bfrom\s+['"]/.test(soFar)) break
          i++
          continue
        }
        i++
        continue
      }
      if (state === LINE_COMMENT) {
        if (c === '\n') state = NORMAL
        i++
        continue
      }
      if (state === BLOCK_COMMENT) {
        if (c === '*' && next === '/') { state = NORMAL; i += 2; continue }
        i++
        continue
      }
      if (state === SQ || state === DQ) {
        const q = state === SQ ? "'" : '"'
        if (c === '\\') { i += 2; continue }
        if (c === q) { state = NORMAL; i++; continue }
        i++
        continue
      }
      if (state === TEMPLATE) {
        if (c === '\\') { i += 2; continue }
        if (c === '`') { state = NORMAL; i++; continue }
        i++
        continue
      }
    }

    const statement = src.slice(start, i).replace(/\s+$/, '')
    const sideEffect = /^import\s+['"]/.test(statement)
    let names = []
    if (!sideEffect) {
      const m = /^import\s+(?:type\s+)?([\s\S]+?)\s+from\s+['"][^'"]+['"]\s*;?$/.exec(statement)
      if (m) names = bindNamesFromClause(m[1])
    }
    out.push({ statement, names })
    i = skipWsAndComments(src, i)
  }

  return out
}

/**
 * True if `name` appears as a code identifier in `region`, ignoring strings
 * and comments. Type positions count. Regex-literal identifiers also count
 * (false-positive preference; regexes are not tokenised).
 */
export function regionUsesName(region, name) {
  let i = 0
  let state = NORMAL
  let depth = 0
  const templateStack = []

  while (i < region.length) {
    const c = region[i]
    const next = region[i + 1]

    if (state === NORMAL) {
      if (c === '/' && next === '/') { state = LINE_COMMENT; i += 2; continue }
      if (c === '/' && next === '*') { state = BLOCK_COMMENT; i += 2; continue }
      if (c === "'") { state = SQ; i++; continue }
      if (c === '"') { state = DQ; i++; continue }
      if (c === '`') { state = TEMPLATE; i++; continue }
      if (c === '{') { depth++; i++; continue }
      if (c === '}') {
        depth--
        if (templateStack.length && depth === templateStack[templateStack.length - 1]) {
          templateStack.pop()
          state = TEMPLATE
        }
        i++
        continue
      }
      if (/[A-Za-z_$]/.test(c)) {
        let j = i + 1
        while (j < region.length && /[\w$]/.test(region[j])) j++
        if (region.slice(i, j) === name) return true
        i = j
        continue
      }
      i++
      continue
    }
    if (state === LINE_COMMENT) {
      if (c === '\n') state = NORMAL
      i++
      continue
    }
    if (state === BLOCK_COMMENT) {
      if (c === '*' && next === '/') { state = NORMAL; i += 2; continue }
      i++
      continue
    }
    if (state === SQ || state === DQ) {
      const q = state === SQ ? "'" : '"'
      if (c === '\\') { i += 2; continue }
      if (c === q) { state = NORMAL; i++; continue }
      i++
      continue
    }
    if (state === TEMPLATE) {
      if (c === '\\') { i += 2; continue }
      if (c === '`') { state = NORMAL; i++; continue }
      if (c === '$' && next === '{') {
        templateStack.push(depth)
        depth++
        state = NORMAL
        i += 2
        continue
      }
      i++
      continue
    }
  }
  return false
}

function usedImportsPreamble(src, region) {
  const used = []
  for (const imp of parseLeadingImports(src)) {
    if (imp.names.length === 0) continue
    if (imp.names.some((n) => regionUsesName(region, n))) {
      used.push(imp.statement)
    }
  }
  if (used.length === 0) return ''
  return `${used.join('\n')}\n\n`
}

export function parseSpec(spec) {
  const hash = spec.indexOf('#')
  if (hash === -1) return { path: spec, kind: 'file' }

  const path = spec.slice(0, hash)
  const frag = spec.slice(hash + 1)

  const range = /^L(\d+)-L(\d+)$/.exec(frag)
  if (range) {
    const from = Number(range[1])
    const to = Number(range[2])
    if (from < 1 || to < from) throw new ExtractError(`bad line range: ${frag}`)
    return { path, kind: 'lines', from, to }
  }

  const noImports = /^([A-Za-z_$][\w$]*)-imports$/.exec(frag)
  if (noImports) {
    return { path, kind: 'symbol', symbol: noImports[1], includeImports: false }
  }

  if (!/^[A-Za-z_$][\w$]*$/.test(frag)) {
    throw new ExtractError(
      `bad fragment: ${frag} (expected a symbol name, <symbol>-imports, or L<n>-L<m>)`,
    )
  }
  return { path, kind: 'symbol', symbol: frag, includeImports: true }
}

export function extract(spec, root = process.cwd()) {
  const parsed = parseSpec(spec)
  const abs = resolve(root, parsed.path)

  let src
  try {
    src = readFileSync(abs, 'utf8')
  } catch {
    throw new ExtractError(`cannot read ${parsed.path}`)
  }

  if (parsed.kind === 'file') return src.replace(/\s+$/, '')

  if (parsed.kind === 'lines') {
    const lines = src.split('\n')
    if (parsed.to > lines.length) {
      throw new ExtractError(`${parsed.path} has ${lines.length} lines; asked for L${parsed.to}`)
    }
    return lines.slice(parsed.from - 1, parsed.to).join('\n').replace(/\s+$/, '')
  }

  const declStart = findSymbolStart(src, parsed.symbol)
  const start = includeLeadingComments(src, declStart)
  const end = matchBraces(src, declStart)
  const region = src.slice(start, end).replace(/^\n+/, '').replace(/\s+$/, '')

  if (parsed.includeImports === false) return region
  return (usedImportsPreamble(src, region) + region).replace(/\s+$/, '')
}

export function langFor(path) {
  const ext = path.slice(path.lastIndexOf('.') + 1)
  return {
    ts: 'ts', tsx: 'tsx', js: 'js', jsx: 'jsx', mjs: 'js', cjs: 'js',
    json: 'json', css: 'css', sql: 'sql', sh: 'bash', py: 'python',
    yml: 'yaml', yaml: 'yaml', md: 'markdown', txt: 'text',
  }[ext] ?? ''
}

const isMain =
  Boolean(process.argv[1]) &&
  fileURLToPath(import.meta.url) === resolve(process.argv[1])
if (isMain) {
  const spec = process.argv[2]
  if (!spec) {
    console.error(
      'usage: node scripts/lib/extract.mjs "<path>[#<symbol>|#<symbol>-imports|#L<a>-L<b>]"',
    )
    process.exit(2)
  }
  try {
    process.stdout.write(extract(spec, process.env.EXTRACT_ROOT || process.cwd()))
  } catch (err) {
    console.error(`extract: ${err.message}`)
    process.exit(1)
  }
}
