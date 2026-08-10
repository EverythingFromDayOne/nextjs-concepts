#!/usr/bin/env node
/**
 * Verify relative markdown links and anchors under docs/.
 *
 * Policy (do not unify with verify-legacy-markers):
 * - Cross-repo links — targets that resolve outside this repository's root —
 *   warn rather than fail when the sibling checkout is missing (roadmap §7.5).
 * - Anything else — targets that resolve inside this repository's root — are
 *   hard failures, split into two reported cases: missing file, and missing
 *   anchor (file exists, heading slug doesn't).
 *
 * Classification is purely by where the resolved *target* lands on disk,
 * never by matching a repo-name substring anywhere (checkout path, frontmatter
 * status, link text, etc.) — a string match is not a reliable signal for
 * where a link points. CI's nested checkout path (`…/nextjs-concepts/
 * nextjs-concepts/…`) used to make every same-repo link look cross-repo,
 * because the checkout directory itself matched the sibling-repo-name
 * pattern the old code searched for — the gate warned on everything and
 * never actually failed on CI.
 *
 * There is no draft exception: a forward link to a not-yet-written corpus
 * path is indistinguishable on disk from a typo, so both are hard failures
 * here. (Draft status still governs verify-code-blocks separately.)
 *
 * Usage: node scripts/verify-links.mjs [root]
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const FENCE = /^\s*(```|~~~)/;
const LINK = /\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;
const INLINE_CODE = /`+[^`]*`+/g;
const HEADING = /^(#{1,6})\s+(.*?)\s*$/;
const SKIP_DIRS = new Set([
  ".git",
  "node_modules",
  "dist",
  "build",
  "coverage",
  ".next",
]);

// This repo's root, derived from this script's own location on disk — never
// from a checkout-path string. `../../<sibling-repo>/…` links resolve outside
// this directory regardless of what the checkout happens to be named.
const REPO_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);

function isOutsideRepo(resolved) {
  const rel = path.relative(REPO_ROOT, resolved);
  return rel === ".." || rel.startsWith(`..${path.sep}`) || path.isAbsolute(rel);
}

function stripFences(text) {
  const out = [];
  let inFence = false;
  let marker = "";
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(FENCE);
    if (m && !inFence) {
      inFence = true;
      marker = m[1];
      out.push("");
      continue;
    }
    if (inFence && line.trim().startsWith(marker)) {
      inFence = false;
      out.push("");
      continue;
    }
    out.push(inFence ? "" : line);
  }
  return out.join("\n");
}

function slugify(heading) {
  let text = heading.trim().toLowerCase();
  text = text.replace(/<[^>]+>/g, "");
  text = text.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1");
  text = text.replace(/[`*_~]/g, "");
  text = text.replace(/[^\w\- ]/g, "");
  return text.replace(/ /g, "-");
}

function walkMarkdown(root) {
  const files = [];
  function walk(dir) {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
      if (SKIP_DIRS.has(ent.name)) continue;
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) walk(full);
      else if (ent.isFile() && ent.name.endsWith(".md")) files.push(full);
    }
  }
  walk(root);
  return files;
}

function anchorsOf(filePath) {
  const seen = new Map();
  const anchors = new Set();
  const body = stripFences(fs.readFileSync(filePath, "utf8"));
  for (const line of body.split(/\r?\n/)) {
    const m = line.match(HEADING);
    if (!m) continue;
    const base = slugify(m[2]);
    if (!base) continue;
    const count = seen.get(base) ?? 0;
    anchors.add(count === 0 ? base : `${base}-${count}`);
    seen.set(base, count + 1);
  }
  return anchors;
}

function main() {
  const rootArg = process.argv[2] ?? "docs";
  const root = path.resolve(rootArg);
  if (!fs.existsSync(root)) {
    console.error(`verify-links: root not found: ${root}`);
    process.exit(1);
  }

  const files = walkMarkdown(root);
  const anchorCache = new Map();
  const failures = [];
  const warnings = [];

  for (const filePath of files) {
    const raw = fs.readFileSync(filePath, "utf8");
    const body = stripFences(raw);
    const lines = body.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].replace(INLINE_CODE, "");
      LINK.lastIndex = 0;
      let match;
      while ((match = LINK.exec(line)) !== null) {
        const target = match[1];
        if (/^(https?:|mailto:)/i.test(target)) continue;

        const hashIdx = target.indexOf("#");
        const filePart = hashIdx === -1 ? target : target.slice(0, hashIdx);
        const anchor = hashIdx === -1 ? "" : target.slice(hashIdx + 1);
        const rel = path.relative(root, filePath);
        const lineno = i + 1;

        let resolved = filePath;
        if (filePart) {
          resolved = path.resolve(path.dirname(filePath), filePart);
          const crossRepo = isOutsideRepo(resolved);
          if (!fs.existsSync(resolved)) {
            const msg = `${rel}:${lineno} — missing file -> ${target}`;
            if (crossRepo) warnings.push(msg);
            else failures.push(msg);
            continue;
          }
          // A same-repo target that resolves to a real file is a hard case
          // from here on; a cross-repo target only ever warns (the sibling
          // checkout, and thus its anchors, may legitimately be absent).
          if (crossRepo) continue;
        }

        if (!anchor || path.extname(resolved) !== ".md") continue;
        if (!anchorCache.has(resolved)) {
          anchorCache.set(resolved, anchorsOf(resolved));
        }
        if (!anchorCache.get(resolved).has(anchor)) {
          const anchorFile = path.relative(root, resolved) || rel;
          const msg = `${rel}:${lineno} — missing anchor "#${anchor}" in ${anchorFile}`;
          failures.push(msg);
        }
      }
    }
  }

  for (const w of warnings) console.warn(`verify-links (warning): ${w}`);
  for (const f of failures) console.error(f);
  console.log(
    `\nchecked ${files.length} file(s); ${failures.length} broken link(s); ${warnings.length} warning(s)`
  );
  process.exit(failures.length ? 1 : 0);
}

main();
