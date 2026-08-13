#!/usr/bin/env node
/**
 * Verify relative markdown links and anchors under docs/.
 *
 * Policy (do not unify with verify-legacy-markers) — four-way classification
 * by where the resolved *target* lands, never by matching a repo-name
 * substring anywhere (checkout path, frontmatter status, link text, etc.):
 *
 * 1. Resolves outside this repository's root
 *      -> WARN. Cross-repo (e.g. into `reactjs-concepts`); the sibling
 *         checkout, and thus its file and its anchors, may legitimately be
 *         absent in this environment.
 * 2. Same-repo, file exists
 *      -> Check the anchor; FAIL if the `#slug` is absent.
 * 3. Same-repo, file missing, but the path (as `concept_folder/article-id`)
 *    appears in `roadmap.md` §3's manifest of the 47 planned articles
 *      -> WARN. Planned, unwritten — every article's "See also" points
 *         forward by design, and under a strict two-way policy CI would stay
 *         red for the life of the project.
 * 4. Same-repo, file missing, not in the roadmap manifest
 *      -> FAIL. A typo, or a link to something nobody planned. This is the
 *         bucket that must reach zero; the roadmap is the only thing that can
 *         tell this case apart from case 3.
 *
 * roadmap.md §3 is parsed as the manifest, never hand-duplicated into a
 * second list here, so the two cannot drift apart.
 *
 * Reported in three buckets: cross-repo warns, planned-forward warns, and
 * hard failures (missing-and-unplanned files, plus missing anchors — an
 * anchor can only be checked on a file that exists, so it is never a
 * cross-repo or planned-forward case).
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
const ROADMAP_PATH = path.join(REPO_ROOT, "roadmap.md");
const CONCEPTS_ROOT = path.join(REPO_ROOT, "docs", "concepts");

// Matches only the start of a `roadmap.md` §3 list item, e.g.
// "6. `caching/cache-components-model` — the thesis article." — anchored to
// the line start so prose elsewhere in the same section (`next/dynamic`,
// `next/font`, `@next/third-parties`, …) can never be mistaken for a planned
// article path.
const ROADMAP_ARTICLE_LINE = /^\d+\.\s+`([a-z][a-z0-9-]*\/[a-z][a-z0-9-]*)`/;

function isOutsideRepo(resolved) {
  const rel = path.relative(REPO_ROOT, resolved);
  return rel === ".." || rel.startsWith(`..${path.sep}`) || path.isAbsolute(rel);
}

/**
 * Parse the 47-article manifest out of roadmap.md §3, keyed by
 * `concept_folder/article-id` — the same shape a resolved same-repo link
 * takes once made relative to `docs/concepts/`. Returns an empty set (with a
 * loud warning) if §3 can't be found or yields no entries, rather than
 * silently treating every forward link as an unplanned typo.
 */
function parseRoadmapManifest(roadmapPath) {
  const manifest = new Set();
  if (!fs.existsSync(roadmapPath)) {
    console.warn(
      `verify-links: roadmap not found at ${roadmapPath}; planned-forward classification disabled`
    );
    return manifest;
  }
  const text = fs.readFileSync(roadmapPath, "utf8");
  const lines = text.split(/\r?\n/);
  let inSection3 = false;
  for (const line of lines) {
    if (/^##\s+3\./.test(line)) {
      inSection3 = true;
      continue;
    }
    if (inSection3 && /^##\s+4\./.test(line)) break;
    if (!inSection3) continue;
    const m = line.match(ROADMAP_ARTICLE_LINE);
    if (m) manifest.add(m[1]);
  }
  if (manifest.size === 0) {
    console.warn(
      `verify-links: parsed 0 entries from ${path.relative(REPO_ROOT, roadmapPath)} §3; ` +
        "planned-forward links will be reported as hard failures. If §3's format changed, " +
        "update ROADMAP_ARTICLE_LINE in this script to match, or propose a format change to §3."
    );
  }
  return manifest;
}

/**
 * A same-repo, missing-file target is "planned" when its path — relative to
 * `docs/concepts/`, extension stripped — matches a manifest entry. Targets
 * outside `docs/concepts/` (e.g. `docs/recipes/…`) never match; §3 only
 * enumerates concept articles.
 */
function roadmapKeyFor(resolved) {
  if (path.extname(resolved) !== ".md") return null;
  const rel = path.relative(CONCEPTS_ROOT, resolved);
  if (rel.startsWith("..") || path.isAbsolute(rel)) return null;
  return rel.slice(0, -".md".length).split(path.sep).join("/");
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

// Returns { slugs: Set<string>, headings: string[] } — the slug set for
// lookup, and the original heading text (in document order) so an anchor
// failure can report what's actually available without opening the file.
function anchorsOf(filePath) {
  const seen = new Map();
  const slugs = new Set();
  const headings = [];
  const body = stripFences(fs.readFileSync(filePath, "utf8"));
  for (const line of body.split(/\r?\n/)) {
    const m = line.match(HEADING);
    if (!m) continue;
    const base = slugify(m[2]);
    if (!base) continue;
    const count = seen.get(base) ?? 0;
    slugs.add(count === 0 ? base : `${base}-${count}`);
    seen.set(base, count + 1);
    headings.push(m[2]);
  }
  return { slugs, headings };
}

function main() {
  const rootArg = process.argv[2] ?? "docs";
  const root = path.resolve(rootArg);
  if (!fs.existsSync(root)) {
    console.error(`verify-links: root not found: ${root}`);
    process.exit(1);
  }

  const manifest = parseRoadmapManifest(ROADMAP_PATH);
  const files = walkMarkdown(root);
  const anchorCache = new Map();
  const failures = [];
  const crossRepoWarnings = [];
  const plannedWarnings = [];

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
            if (crossRepo) {
              crossRepoWarnings.push(msg);
            } else {
              const roadmapKey = roadmapKeyFor(resolved);
              if (roadmapKey && manifest.has(roadmapKey)) {
                plannedWarnings.push(`${msg} (planned, unwritten — roadmap.md §3: ${roadmapKey})`);
              } else {
                failures.push(msg);
              }
            }
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
        const { slugs, headings } = anchorCache.get(resolved);
        if (!slugs.has(anchor)) {
          const anchorFile = path.relative(root, resolved) || rel;
          const available = headings.length
            ? headings.join(", ")
            : "(no headings found)";
          const msg = `${rel}:${lineno} — ${anchorFile}#${anchor} (available: ${available})`;
          failures.push(msg);
        }
      }
    }
  }

  for (const w of crossRepoWarnings) console.warn(`verify-links (cross-repo warning): ${w}`);
  for (const w of plannedWarnings) console.warn(`verify-links (planned-forward warning): ${w}`);
  for (const f of failures) console.error(`verify-links (FAIL): ${f}`);
  console.log(
    `\nchecked ${files.length} file(s); ` +
      `${failures.length} hard failure(s); ` +
      `${crossRepoWarnings.length} cross-repo warning(s); ` +
      `${plannedWarnings.length} planned-forward warning(s)`
  );
  process.exit(failures.length ? 1 : 0);
}

main();
