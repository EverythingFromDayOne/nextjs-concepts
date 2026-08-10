#!/usr/bin/env node
/**
 * Fail if banned legacy Next.js surfaces appear outside an allowed context.
 *
 * Allowed contexts (any one is enough):
 *   1. Nearest preceding heading matches
 *      /then vs now|how this evolved|migration|common mistakes/i
 *   2. Fenced code block whose preceding line OR first content line carries
 *      the // legacy: marker comment
 *   3. Inside a <!-- legacy-ok:start reason=… --> … <!-- legacy-ok:end -->
 *      region (reason= required and non-empty; no nesting; must close)
 *
 * Banned tokens come from docs/evolution-ledger.md rows whose Ban column is
 * `yes`. Rows with Ban `no` are skipped — put that decision in the ledger,
 * not in a hardcoded exclusion list here.
 *
 * Unlike verify-code-blocks (draft softens) and verify-links (draft forward
 * links warn), this gate hard-fails for every status.
 *
 * Usage: node scripts/verify-legacy-markers.mjs [--verbose] [docsRoot] [ledgerPath]
 */
import fs from "node:fs";
import path from "node:path";

const SECTION_OK = /then vs now|how this evolved|migration|common mistakes/i;
const LEGACY_MARKER =
  /\/\/\s*legacy:\s*Next\s*<\s*16\s+implicit-caching model\s*—\s*see docs\/evolution-ledger\.md/;
const HEADING = /^(#{1,6})\s+(.*?)\s*$/;
const FENCE_OPEN = /^(\s*)(```|~~~)([^\n]*)$/;
const REGION_START = /<!--\s*legacy-ok:start\b([^>]*)-->/;
const REGION_END = /<!--\s*legacy-ok:end\s*-->/;
const REASON_ATTR = /\breason=(\S[\s\S]*?)\s*$/;

function parseBannedTokens(ledgerText) {
  const tokens = new Set();
  const lines = ledgerText.split(/\r?\n/);
  let inTable = false;
  let banCol = -1;
  let oldCol = -1;

  for (const line of lines) {
    if (!line.startsWith("|")) {
      inTable = false;
      banCol = -1;
      oldCol = -1;
      continue;
    }
    const cells = line.split("|").map((c) => c.trim());
    if (cells.length < 3) continue;
    const cols = cells.slice(1, -1);

    if (cols.every((c) => /^[-:\s]+$/.test(c))) {
      inTable = true;
      continue;
    }

    const headerIdx = cols.findIndex((c) => c.toLowerCase() === "old surface");
    if (headerIdx !== -1) {
      inTable = true;
      oldCol = headerIdx;
      banCol = cols.findIndex((c) => c.toLowerCase() === "ban");
      continue;
    }

    if (!inTable || oldCol === -1) continue;

    const oldSurface = cols[oldCol] ?? "";
    const ban = (banCol === -1 ? "yes" : cols[banCol] ?? "").toLowerCase();

    if (/^\*\(new/i.test(oldSurface) || oldSurface.includes("*(new, no predecessor)*")) {
      continue;
    }
    if (ban !== "yes") continue;

    extractTokens(oldSurface, tokens);
  }

  return [...tokens].sort((a, b) => b.length - a.length);
}

function extractTokens(cell, tokens) {
  const codeSpans = cell.matchAll(/`([^`]+)`/g);
  for (const m of codeSpans) {
    const raw = m[1].trim();
    if (!raw) continue;
    for (const part of raw.split(/\s*\/\s*/)) {
      addTokenVariants(part.trim(), tokens);
    }
  }
}

function addTokenVariants(token, tokens) {
  if (!token) return;
  if (token.length < 3 || /^[\[\](){},.\s]+$/.test(token)) return;

  tokens.add(token);

  const assign = token.match(/^(export const \w+)\s*=/);
  if (assign) tokens.add(assign[1]);

  if (token.startsWith("fetch(")) {
    tokens.add("next: { revalidate");
    tokens.add("next:{ revalidate");
  }

  if (token.includes("experimental.ppr")) tokens.add("experimental.ppr");
  if (token.includes("experimental_ppr")) tokens.add("experimental_ppr");
  if (token.includes("experimental.dynamicIO")) {
    tokens.add("experimental.dynamicIO");
  }
  if (token.includes("experimental.useCache")) {
    tokens.add("experimental.useCache");
  }
}

function walkMarkdown(root) {
  const files = [];
  function walk(dir) {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
      if (ent.name === "node_modules" || ent.name === ".git") continue;
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) walk(full);
      else if (ent.isFile() && ent.name.endsWith(".md")) files.push(full);
    }
  }
  walk(root);
  return files;
}

function parseReason(attrs) {
  const m = REASON_ATTR.exec(attrs.trim());
  if (!m) return null;
  const reason = m[1].trim();
  return reason.length > 0 ? reason : null;
}

function checkFile(filePath, root, tokens) {
  const rel = path.relative(root, filePath).replace(/\\/g, "/");
  if (rel === "evolution-ledger.md") {
    return { failures: [], regions: [] };
  }

  const text = fs.readFileSync(filePath, "utf8");
  const lines = text.split(/\r?\n/);
  const failures = [];
  const regions = [];

  let currentHeading = "";
  let inFence = false;
  let fenceLegacy = false;
  let fenceSawContent = false;
  let prevLine = "";
  let inRegion = false;
  let regionStartLine = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineno = i + 1;

    const start = REGION_START.exec(line);
    if (start) {
      if (inRegion) {
        failures.push(
          `${rel}:${lineno} — nested legacy-ok:start (previous start at line ${regionStartLine})`
        );
      }
      const reason = parseReason(start[1] ?? "");
      if (!reason) {
        failures.push(
          `${rel}:${lineno} — legacy-ok:start missing required non-empty reason= attribute`
        );
        // Still open a region so a later end can close it, but do not count it.
        inRegion = true;
        regionStartLine = lineno;
      } else {
        inRegion = true;
        regionStartLine = lineno;
        regions.push({ file: rel, line: lineno, reason });
      }
      prevLine = line;
      continue;
    }

    if (REGION_END.test(line)) {
      if (!inRegion) {
        failures.push(`${rel}:${lineno} — legacy-ok:end without a matching start`);
      }
      inRegion = false;
      regionStartLine = 0;
      prevLine = line;
      continue;
    }

    const fence = line.match(FENCE_OPEN);
    if (fence) {
      if (!inFence) {
        inFence = true;
        fenceLegacy = LEGACY_MARKER.test(prevLine);
        fenceSawContent = false;
      } else {
        inFence = false;
        fenceLegacy = false;
        fenceSawContent = false;
      }
      prevLine = line;
      continue;
    }

    if (inFence && !fenceSawContent && line.trim() !== "") {
      fenceSawContent = true;
      if (LEGACY_MARKER.test(line)) fenceLegacy = true;
    }

    const heading = line.match(HEADING);
    if (heading && !inFence) {
      currentHeading = heading[2].trim();
      prevLine = line;
      continue;
    }

    const sectionOk = SECTION_OK.test(currentHeading);
    const allowed = sectionOk || (inFence && fenceLegacy) || inRegion;

    if (!allowed) {
      for (const token of tokens) {
        if (line.includes(token)) {
          failures.push(
            `${rel}:${lineno} — banned legacy surface '${token}' outside a Then-vs-now section, legacy-marked block, or legacy-ok region`
          );
          break;
        }
      }
    }

    prevLine = line;
  }

  if (inRegion) {
    failures.push(
      `${rel}:${regionStartLine} — unclosed legacy-ok:start (reached EOF without legacy-ok:end)`
    );
  }

  return { failures, regions };
}

function main() {
  const argv = process.argv.slice(2);
  const verbose = argv.includes("--verbose");
  const positional = argv.filter((a) => a !== "--verbose");
  const docsRoot = path.resolve(positional[0] ?? "docs");
  const ledgerPath = path.resolve(
    positional[1] ?? path.join(docsRoot, "evolution-ledger.md")
  );

  if (!fs.existsSync(ledgerPath)) {
    console.error(`verify-legacy-markers: ledger not found: ${ledgerPath}`);
    process.exit(1);
  }
  if (!fs.existsSync(docsRoot)) {
    console.error(`verify-legacy-markers: docs root not found: ${docsRoot}`);
    process.exit(1);
  }

  const tokens = parseBannedTokens(fs.readFileSync(ledgerPath, "utf8"));
  if (tokens.length === 0) {
    console.error(
      "verify-legacy-markers: parsed zero Ban=yes tokens from evolution ledger"
    );
    process.exit(1);
  }

  console.log(`parsed ${tokens.length} banned token(s) from evolution ledger (Ban=yes)`);

  const files = walkMarkdown(docsRoot);
  const failures = [];
  const regions = [];
  for (const file of files) {
    const result = checkFile(file, docsRoot, tokens);
    failures.push(...result.failures);
    regions.push(...result.regions);
  }

  for (const f of failures) console.error(f);

  if (verbose) {
    for (const r of regions) {
      console.log(`${r.file}:${r.line} — ${r.reason}`);
    }
  }

  const regionFiles = new Set(regions.map((r) => r.file)).size;
  console.log(
    `verify-legacy-markers: ${files.length} file(s); ${failures.length} failure(s); ${regions.length} legacy-ok region(s) across ${regionFiles} file(s)`
  );
  process.exit(failures.length ? 1 : 0);
}

main();
