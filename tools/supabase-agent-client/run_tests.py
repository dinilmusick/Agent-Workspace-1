#!/usr/bin/env python3
"""Deterministic test entry point for Agent Compute Workspace."""

import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent
result = subprocess.run(
    [sys.executable, "-m", "unittest", "discover", "-s", str(root), "-p", "test_*.py"],
    cwd=root,
)
raise SystemExit(result.returncode)
