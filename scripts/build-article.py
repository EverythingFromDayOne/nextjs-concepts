#!/usr/bin/env python3
"""NOT PORTED — copy from a sibling repo

Expected sources (in order):
  ../reactjs-concepts/scripts/build-article.py
  ../dsa-concepts/scripts/build-article.py

Neither sibling had this file at scaffold time (2026-08-10).
Do not invent a second implementation that will drift.
"""
from __future__ import annotations

import sys


def main() -> int:
    print(
        "NOT PORTED — copy from a sibling repo (build-article.py)",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
