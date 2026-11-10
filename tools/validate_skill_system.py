#!/usr/bin/env python3
"""Validate the repository-side deterministic skill-system contract."""

from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
MATRIX = ROOT / "docs/skill-system/reconciliation-matrix.md"
SKILL = ROOT / "skills/skill-system-reconciliation/SKILL.md"
MANIFEST = ROOT / "skills/skill-system-reconciliation/manifest.json"

def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)

for path in (MATRIX, SKILL, MANIFEST):
    if not path.is_file():
        fail(f"missing required file: {path}")

manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
if manifest.get("slug") != "skill-system-reconciliation":
    fail("manifest slug mismatch")
if manifest.get("canonicalState") != "supabase":
    fail("canonical state must remain Supabase")
if set(manifest.get("requiredTools", [])) != {"github", "supabase"}:
    fail("required tool contract mismatch")

matrix = MATRIX.read_text(encoding="utf-8")
skill = SKILL.read_text(encoding="utf-8")
combined = (matrix + "\n" + skill).lower()

for marker in [
    "exactly one primary coding workflow",
    "goals precede child tasks",
    "evidence is attached before terminal state",
    "independent verification is required before completion",
    "what remains?",
]:
    if marker not in combined:
        fail(f"missing invariant marker: {marker}")

for workflow in ["newRepo", "existingFeature", "implementationPush", "repositoryReconciliation"]:
    if workflow.lower() not in combined:
        fail(f"missing workflow classification: {workflow}")

print("PASS: deterministic skill-system repository contract is internally consistent")
