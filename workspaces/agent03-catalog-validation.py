#!/usr/bin/env python3
"""Validate Agent 03 catalog pin changes and the canonical acquisition controller."""
from __future__ import annotations
import compileall
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "docs/template-portfolio-catalog.md"
EXPECTED = {
    "tpl-ai-ragflow": ("main", "Apache-2.0", "03b0c0ae04ab30e44796b927a3c0229b1a440358"),
    "tpl-bi-superset": ("master", "Apache-2.0", "8d5f06e5250230e55f7d953ab807af271d1ed01b"),
    "tpl-data-meltano": ("main", "MIT", "3913352432f32632e16807142111455d5f64cb89"),
    "tpl-data-airflow": ("main", "Apache-2.0", "6c2e7b3646062af0c72528869a211274a775e8c3"),
}
OLD = {
    "tpl-ai-ragflow": "1fc73d125f0081dc3090835a96a4e45e13055e84",
    "tpl-bi-superset": "58a1a5c7e8f759383573ba15ba509e8d1bc49015",
    "tpl-data-meltano": "23fab6f99554b0de7ce17d6ede3b8a45bc3234a9",
    "tpl-data-airflow": "e024d4c15a52a843c28aa773c2d5db69fe21deea",
}
def main() -> int:
    text = CATALOG.read_text(encoding="utf-8")
    for destination, (branch, spdx, sha) in EXPECTED.items():
        rows = [line for line in text.splitlines() if line.startswith("|") and line.split("|")[3].strip() == f"`{destination}`"]
        assert len(rows) == 1, f"{destination}: expected one catalog table row, found {len(rows)}"
        row = rows[0]
        assert f"| {branch} | {spdx} |" in row, f"{destination}: branch/SPDX mismatch"
        assert f"`{sha}`" in row, f"{destination}: current SHA missing"
        assert f"`{OLD[destination]}`" not in row, f"{destination}: stale SHA remains in row"
    for marker in ("wildcard CORS", "BlueOak-1.0.0", "2.46.0", "AG Grid", "pydantic-ai", "SQLToolsetConnectionError", "pg_advisory_lock", "oxfmt 0.75.0→0.77.0"):
        assert marker.lower() in text.lower(), f"missing review marker: {marker}"
    compiled = compileall.compile_dir(str(ROOT / "tools/github/acquisition"), quiet=1, force=True)
    assert compiled, "acquisition controller compileall failed"
    cmd = [sys.executable, "-m", "unittest", "discover", "-s",
           str(ROOT / "tools/github/acquisition"), "-p", "test_*.py", "-v"]
    result = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    print(result.stdout)
    print(result.stderr, file=sys.stderr)
    print(json.dumps({"catalog_rows": sorted(EXPECTED), "compileall": compiled,
                      "controller_unittest_exit": result.returncode}, indent=2))
    return result.returncode
if __name__ == "__main__":
    raise SystemExit(main())
