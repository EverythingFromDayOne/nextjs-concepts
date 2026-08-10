#!/usr/bin/env python3
"""
build-article.py — turn an article template into a finished article.

Human-authored prose lives in `<article>.md.tpl`. Code never does. The template
carries tokens; this script resolves them and writes `<article>.md`.

Tokens
    {EXTRACT:demos/next-lab/lib/billing.ts#getPlans}
        Replaced by a fenced code block containing the verbatim region (plus
        the import statements that region uses), preceded by an HTML provenance
        comment that `verify-code-blocks.mjs` reads back. Use `#getPlans-imports`
        to emit the region alone.

    {EXTRACT:demos/next-lab/app/page.tsx#L1-L20}
        Same, for a line range.

    {SOMETHING_ELSE}
        Any other ALL_CAPS token is an unfilled prose placeholder. The build
        fails and lists them, so a half-written article cannot be committed as
        if it were finished.

Extraction is delegated to scripts/lib/extract.mjs so the builder and the
verifier can never disagree about what a spec means.

usage:
    python3 scripts/build-article.py docs/concepts/caching/use-cache-directive.md.tpl
    python3 scripts/build-article.py --all
    python3 scripts/build-article.py --check <tpl>   # verify, write nothing
exit:
    0 written (or, with --check, up to date)
    1 extraction failure, unfilled placeholder, or --check drift
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXTRACTOR = ROOT / "scripts" / "lib" / "extract.mjs"

EXTRACT_TOKEN = re.compile(r"\{EXTRACT:([^}]+)\}")
ANY_TOKEN = re.compile(r"\{([A-Z][A-Z0-9_]*)\}")

LANG_BY_EXT = {
    ".ts": "ts", ".tsx": "tsx", ".js": "js", ".jsx": "jsx",
    ".mjs": "js", ".cjs": "js", ".json": "json", ".css": "css",
    ".sql": "sql", ".sh": "bash", ".py": "python",
    ".yml": "yaml", ".yaml": "yaml", ".md": "markdown",
    ".txt": "text",
}


class BuildError(Exception):
    pass


def lang_for(spec: str) -> str:
    path = spec.split("#", 1)[0]
    return LANG_BY_EXT.get(Path(path).suffix, "")


def extract(spec: str) -> str:
    if not EXTRACTOR.exists():
        raise BuildError(f"extractor missing: {EXTRACTOR.relative_to(ROOT)}")
    proc = subprocess.run(
        ["node", str(EXTRACTOR), spec],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if proc.returncode != 0:
        raise BuildError(proc.stderr.strip() or f"extract failed for {spec}")
    return proc.stdout


def render(template_text: str, tpl_rel: str) -> str:
    failures: list[str] = []

    def replace(match: re.Match[str]) -> str:
        spec = match.group(1).strip()
        try:
            code = extract(spec)
        except BuildError as err:
            failures.append(f"{tpl_rel}: {err}")
            return match.group(0)
        return (
            f"<!-- extract: {spec} -->\n"
            f"```{lang_for(spec)}\n"
            f"{code}\n"
            f"```"
        )

    out = EXTRACT_TOKEN.sub(replace, template_text)

    if failures:
        raise BuildError("\n".join(failures))

    leftovers = sorted(set(ANY_TOKEN.findall(out)))
    if leftovers:
        listed = ", ".join(f"{{{t}}}" for t in leftovers)
        raise BuildError(f"{tpl_rel}: unfilled placeholder(s): {listed}")

    return out


def build_one(tpl: Path, check_only: bool) -> bool:
    tpl_rel = str(tpl.relative_to(ROOT))
    if not tpl.name.endswith(".md.tpl"):
        raise BuildError(f"{tpl_rel}: expected a .md.tpl file")

    out_path = tpl.with_name(tpl.name[: -len(".tpl")])
    rendered = render(tpl.read_text(encoding="utf-8"), tpl_rel)
    if not rendered.endswith("\n"):
        rendered += "\n"

    if check_only:
        current = out_path.read_text(encoding="utf-8") if out_path.exists() else None
        if current != rendered:
            print(f"build-article: DRIFT {out_path.relative_to(ROOT)}", file=sys.stderr)
            return False
        print(f"build-article: ok    {out_path.relative_to(ROOT)}")
        return True

    out_path.write_text(rendered, encoding="utf-8")
    print(f"build-article: wrote {out_path.relative_to(ROOT)}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("templates", nargs="*", help="paths to .md.tpl files")
    parser.add_argument("--all", action="store_true", help="build every .md.tpl under docs/")
    parser.add_argument("--check", action="store_true", help="verify without writing")
    args = parser.parse_args()

    if args.all:
        targets = sorted((ROOT / "docs").rglob("*.md.tpl"))
    else:
        targets = [Path(t).resolve() for t in args.templates]

    if not targets:
        print("build-article: no templates found (nothing to do)")
        return 0

    ok = True
    for tpl in targets:
        try:
            if not build_one(tpl, args.check):
                ok = False
        except BuildError as err:
            print(f"build-article: {err}", file=sys.stderr)
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
