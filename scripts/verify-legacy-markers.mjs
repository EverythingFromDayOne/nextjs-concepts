#!/usr/bin/env node
/**
 * Fail if banned legacy Next.js surfaces appear outside Then-vs-now /
 * migration sections or legacy-marked fenced blocks.
 *
 * Banned tokens are parsed from the "Old surface" column of
 * docs/evolution-ledger.md — do not hardcode a second copy.
 *
 * Usage: node scripts/verify-legacy-markers.mjs [docsRoot] [ledgerPath]
 */
import fs from "node:fs";
import path from "node:path";

const SECTION_OK = /then vs now|how this evolved|migration/i;
const LEGACY_MARKER =
  /\/\/\s*legacy:\s*Next\s*<\s*16\s+implicit-caching model\s*—\s*see docs\/evolution-ledger\.md/;
const HEADING = /^(#{1,6})\s+(.*?)\s*$/;
const FENCE_OPEN = /^(\s*)(```|~~~)([^\n]*)$/;

function parseOldSurfaces(ledgerText) {
  const tokens = new Set();
  const lines = ledgerText.split(/\r?\n/);
  let inTable = false;

  for (const line of lines) {
    if (!line.startsWith("|")) {
      inTable = false;
      continue;
    }
    const cells = line.split("|").map((c) => c.trim());
    // markdown table rows: ["", col0, col1, ..., ""]
    if (cells.length < 3) continue;
    const first = cells[1];
    if (/^[-:\s]+$/.test(first)) {
      inTable = true;
      continue;
    }
    if (!inTable && first.toLowerCase() === "old surface") {
      inTable = true;
      continue;
    }
    if (!inTable) continue;
    if (first.toLowerCase() === "old surface") continue;

    // Skip pure "new, no predecessor" rows — no old token to ban.
    if (/^\*\(new/i.test(first) || first.includes("*(new, no predecessor)*")) {
      continue;
    }

    extractTokens(first, tokens);
  }

  return [...tokens].sort((a, b) => b.length - a.length);
}

function extractTokens(cell, tokens) {
  // Prefer fenced code spans; also pick bare identifiers when useful.
  const codeSpans = cell.matchAll(/`([^`]+)`/g);
  for (const m of codeSpans) {
    const raw = m[1].trim();
    if (!raw) continue;
    // Split alternates: `unstable_noStore()` / `noStore()`
    for (const part of raw.split(/\s*\/\s*/)) {
      addTokenVariants(part.trim(), tokens);
    }
  }

  // Non-code prose tokens that still name banned surfaces.
  if (/unmount-on-navigate/i.test(cell)) {
    tokens.add("unmount-on-navigate");
  }
  if (/eager prefetch/i.test(cell)) {
    tokens.add("eager prefetch");
  }
  if (/\bWebpack\b/.test(cell)) {
    tokens.add("Webpack");
  }
}

function addTokenVariants(token, tokens) {
  if (!token || token === "*(new, no predecessor)*") return;

  // Too short / punctuation-only — e.g. `[]` from "returning `[]`".
  if (token.length < 3 || /^[\[\](){},.\s]+$/.test(token)) return;

  tokens.add(token);

  // Also ban the config key form without the assignment value.
  // e.g. export const dynamic = 'force-dynamic' → also match export const dynamic
  const assign = token.match(/^(export const \w+)\s*=/);
  if (assign) tokens.add(assign[1]);

  // fetch(url, { cache, next: { revalidate, tags } }) → fetch with next.revalidate is hard;
  // keep the full token and a shorter distinctive form.
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

function checkFile(filePath, root, tokens) {
  const rel = path.relative(root, filePath);
  // The ledger itself defines the old surfaces — skip it.
  if (rel.replace(/\\/g, "/") === "evolution-ledger.md") return [];

  const text = fs.readFileSync(filePath, "utf8");
  const lines = text.split(/\r?\n/);
  const failures = [];

  let currentHeading = "";
  let inFence = false;
  let fenceLegacy = false;
  let prevLine = "";

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineno = i + 1;

    const fence = line.match(FENCE_OPEN);
    if (fence) {
      if (!inFence) {
        inFence = true;
        fenceLegacy = LEGACY_MARKER.test(prevLine);
      } else {
        inFence = false;
        fenceLegacy = false;
      }
      prevLine = line;
      continue;
    }

    const heading = line.match(HEADING);
    if (heading && !inFence) {
      currentHeading = heading[2].trim();
      prevLine = line;
      continue;
    }

    const sectionOk = SECTION_OK.test(currentHeading);
    const allowed = sectionOk || (inFence && fenceLegacy);

    if (!allowed) {
      for (const token of tokens) {
        if (line.includes(token)) {
          failures.push(
            `${rel}:${lineno} — banned legacy surface '${token}' outside a Then-vs-now section or legacy-marked block`
          );
          // One failure per line is enough signal.
          break;
        }
      }
    }

    prevLine = line;
  }

  return failures;
}

function main() {
  const docsRoot = path.resolve(process.argv[2] ?? "docs");
  const ledgerPath = path.resolve(
    process.argv[3] ?? path.join(docsRoot, "evolution-ledger.md")
  );

  if (!fs.existsSync(ledgerPath)) {
    console.error(`verify-legacy-markers: ledger not found: ${ledgerPath}`);
    process.exit(1);
  }
  if (!fs.existsSync(docsRoot)) {
    console.error(`verify-legacy-markers: docs root not found: ${docsRoot}`);
    process.exit(1);
  }

  const tokens = parseOldSurfaces(fs.readFileSync(ledgerPath, "utf8"));
  if (tokens.length === 0) {
    console.error(
      "verify-legacy-markers: parsed zero tokens from Old surface column"
    );
    process.exit(1);
  }

  console.log(`parsed ${tokens.length} banned token(s) from evolution ledger`);

  const files = walkMarkdown(docsRoot);
  const failures = [];
  for (const file of files) {
    failures.push(...checkFile(file, docsRoot, tokens));
  }

  for (const f of failures) console.error(f);
  console.log(
    `\nchecked ${files.length} file(s); ${failures.length} legacy violation(s)`
  );
  process.exit(failures.length ? 1 : 0);
}

main();
