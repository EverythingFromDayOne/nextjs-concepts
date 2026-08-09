#!/usr/bin/env node
/**
 * Verify relative markdown links and anchors under docs/.
 *
 * Sibling repos did not ship verify-links.mjs at scaffold time.
 * Behaviour mirrors nestjs-concepts/scripts/check-links.py contract:
 * exit non-zero on failure, print file:line.
 *
 * Usage: node scripts/verify-links.mjs [root]
 */
import fs from "node:fs";
import path from "node:path";

const FENCE = /^\s*(```|~~~)/;
const LINK = /\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;
const INLINE_CODE = /`+[^`]*`+/g;
const HEADING = /^(#{1,6})\s+(.*?)\s*#*\s*$/;
const SKIP_DIRS = new Set([
  ".git",
  "node_modules",
  "dist",
  "build",
  "coverage",
  ".next",
]);

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

  for (const filePath of files) {
    const body = stripFences(fs.readFileSync(filePath, "utf8"));
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
          if (!fs.existsSync(resolved)) {
            failures.push(`${rel}:${lineno} — missing file -> ${target}`);
            continue;
          }
        }

        if (!anchor || path.extname(resolved) !== ".md") continue;
        if (!anchorCache.has(resolved)) {
          anchorCache.set(resolved, anchorsOf(resolved));
        }
        if (!anchorCache.get(resolved).has(anchor)) {
          failures.push(`${rel}:${lineno} — missing anchor -> ${target}`);
        }
      }
    }
  }

  for (const f of failures) console.error(f);
  console.log(
    `\nchecked ${files.length} file(s); ${failures.length} broken link(s)`
  );
  process.exit(failures.length ? 1 : 0);
}

main();
