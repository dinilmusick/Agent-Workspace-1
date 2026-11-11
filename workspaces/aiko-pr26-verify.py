#!/usr/bin/env python3
import base64
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path.cwd()
RESULTS = ROOT / "results"
RESULTS.mkdir(exist_ok=True)
TARGET = ROOT / "target-aiko"
REF = "test/fod-absorption-regression-gates"
REPO = "https://github.com/dinilmusick/Aiko.git"
report = {"repository": "dinilmusick/Aiko", "ref": REF, "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "checks": []}

def run(name, command, cwd=TARGET, timeout=1200, env=None):
    started = time.time()
    print("\n===== " + name + " =====", flush=True)
    try:
        p = subprocess.run(command, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        output = p.stdout
        code = p.returncode
    except subprocess.TimeoutExpired as e:
        output = (e.stdout or "") + "\nTIMEOUT after " + str(timeout) + " seconds"
        code = 124
    (RESULTS / (name.replace(":", "_").replace(" ", "_") + ".log")).write_text(output, encoding="utf-8")
    print(output[-18000:], flush=True)
    item = {"name": name, "command": command, "exit_code": code, "duration_seconds": round(time.time() - started, 2), "log": name.replace(":", "_").replace(" ", "_") + ".log"}
    report["checks"].append(item)
    print("RESULT " + json.dumps(item), flush=True)
    return code

token = os.environ.pop("PRIVATE_REPO_TOKEN", None)
clone_env = os.environ.copy()
if token:
    basic = base64.b64encode(("x-access-token:" + token).encode("utf-8")).decode("ascii")
    clone_env["GIT_CONFIG_COUNT"] = "1"
    clone_env["GIT_CONFIG_KEY_0"] = "http.https://github.com/.extraheader"
    clone_env["GIT_CONFIG_VALUE_0"] = "AUTHORIZATION: basic " + basic
clone_code = run("clone_target", ["git", "clone", "--depth", "1", "--branch", REF, REPO, str(TARGET)], cwd=ROOT, timeout=300, env=clone_env)
token = None
clone_env.clear()
if clone_code == 0:
    report["head_sha"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=TARGET, text=True).strip()
    package = json.loads((TARGET / "package.json").read_text())
    report["package_scripts"] = package.get("scripts", {})
    install_cmd = ["npm", "install", "--include=optional"]
    install_code = run("dependency_install", install_cmd, timeout=1200)
    if install_code == 0:
        commands = [
            ("lint", ["npm", "run", "lint"]),
            ("system_env", ["npm", "run", "test:system-env"]),
            ("unit_integration", ["npm", "run", "test:integration"]),
            ("architecture_prebuild", ["npm", "run", "test:architecture"]),
            ("fullstack_build", ["npm", "run", "build:fullstack"]),
            ("api_build", ["npm", "run", "build:api"]),
            ("architecture_postbuild", ["npm", "run", "test:architecture"]),
            ("skipo_validator", ["python3", "checklists/aiko_skipo_validator.py", "."]),
        ]
        for name, cmd in commands:
            run(name, cmd, timeout=1200)
    else:
        report["checks"].append({"name": "dependent_checks", "exit_code": None, "skipped": "dependency installation failed"})
else:
    report["checks"].append({"name": "dependent_checks", "exit_code": None, "skipped": "target clone failed"})

report["finished_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
report["overall"] = "PASS" if report.get("head_sha") and all(c.get("exit_code") == 0 for c in report["checks"]) else "FAIL"
(RESULTS / "verification-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("\nFINAL_REPORT=" + json.dumps(report), flush=True)
sys.exit(0 if report["overall"] == "PASS" else 1)

# Trigger exact-head verification from the base-branch workflow.

# PR synchronize event: rerun exact-head validation.
