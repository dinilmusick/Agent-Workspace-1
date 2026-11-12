#!/usr/bin/env python3
"""Validate owner-authorized private acquisition requests against the live catalog."""
from __future__ import annotations
import base64, json, os, re, sys, uuid, urllib.error, urllib.request, urllib.parse
from typing import Any

API = "https://api.github.com"
WORKSPACE = "dinilmusick/Agent-Workspace-1"
CATALOG_PATH = "docs/template-portfolio-catalog.md"
APPROVAL_URL = f"https://github.com/{WORKSPACE}/blob/main/{CATALOG_PATH}"
OPEN_SOURCE_IDS = {
    "MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "0BSD",
    "Zlib", "PostgreSQL", "Unlicense", "BSL-1.0", "BlueOak-1.0.0",
    "AFL-3.0", "Artistic-2.0", "CDDL-1.0", "CDDL-1.1", "CPL-1.0",
    "EPL-1.0", "EPL-2.0", "EUPL-1.1", "EUPL-1.2", "IPL-1.0",
    "MPL-1.1", "MPL-2.0", "OSL-3.0", "Python-2.0", "PSF-2.0",
    "Ruby", "UPL-1.0", "ZPL-2.1", "MulanPSL-2.0", "OpenSSL",
    "GPL-2.0", "GPL-2.0-only", "GPL-2.0-or-later",
    "GPL-3.0", "GPL-3.0-only", "GPL-3.0-or-later",
    "LGPL-2.1", "LGPL-2.1-only", "LGPL-2.1-or-later",
    "LGPL-3.0", "LGPL-3.0-only", "LGPL-3.0-or-later",
    "AGPL-3.0", "AGPL-3.0-only", "AGPL-3.0-or-later",
}

def validate_request_shape(req: Any) -> dict[str, str]:
    if not isinstance(req, dict):
        raise ValueError("Issue body must be a raw JSON object.")
    required = {"source_repository", "source_commit", "target_repository", "category", "acquisition_mode", "approval_record"}
    if set(req) != required:
        raise ValueError(f"Request keys must be exactly the documented set; missing={sorted(required-set(req))}, extra={sorted(set(req)-required)}.")
    source, target, commit = req["source_repository"], req["target_repository"], req["source_commit"]
    category, mode, approval = req["category"], req["acquisition_mode"], req["approval_record"]
    if not isinstance(source, str) or not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9_.-]{0,98}[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9_.-]{0,98}[A-Za-z0-9])?", source):
        raise ValueError("source_repository must be a valid owner/repository name.")
    if any(part in {".", ".."} for part in source.split("/")):
        raise ValueError("Invalid source repository path component.")
    if not isinstance(target, str) or not re.fullmatch(r"tpl-[a-z0-9]+(?:-[a-z0-9]+)*", target):
        raise ValueError("target_repository must use tpl-kebab-case.")
    if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("source_commit must be a full 40-character lowercase SHA.")
    if not isinstance(category, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 &+()/.,'-]{0,99}", category):
        raise ValueError("category must be 1-100 safe printable characters.")
    if mode not in {"mirror", "reference-only"}:
        raise ValueError("acquisition_mode must be mirror or reference-only.")
    if approval != APPROVAL_URL:
        raise ValueError(f"approval_record must be the canonical catalog URL: {APPROVAL_URL}")
    return {"source": source, "target": target, "source_commit": commit, "category": category, "mode": mode, "approval_record": approval}

def assert_exact_head(requested: str, live: str) -> None:
    if requested != live:
        raise ValueError(f"Stale source pin: catalog={requested} live_default_branch_head={live}. Refresh and review the catalog before acquisition.")

def catalog_authorization(catalog: str, request: dict[str, str]) -> dict[str, str] | None:
    source = request.get("source", request.get("source_repository", "")).lower()
    target = request.get("target", request.get("target_repository", "")).lower()
    commit = request["source_commit"].lower()
    mode = None
    for line in catalog.splitlines():
        heading = line.strip().lower()
        if heading.startswith("## "):
            if "additional full-source private research mirrors" in heading:
                mode = "mirror"
            elif "additional reference-only candidates" in heading:
                mode = "reference-only"
            else:
                mode = None
        if mode is None or not line.lstrip().startswith("|"):
            continue
        cells = [cell.strip() for cell in line.split("|")]
        if len(cells) < 6:
            continue
        source_match = re.search(r"https://github\.com/([^/]+)/([^/)\s]+)", cells[2], re.IGNORECASE)
        if not source_match:
            continue
        row_source = f"{source_match.group(1)}/{source_match.group(2)}".lower()
        row_target = cells[3].strip().strip("`").lower()
        row_branch = cells[4].strip().strip("`")
        row_category = cells[1].strip().strip("`")
        if mode == "mirror":
            if len(cells) < 7:
                continue
            row_license = cells[5].strip().strip("`")
            row_commit = cells[6].strip().strip("`").lower()
        else:
            row_license = "NOASSERTION"
            row_commit = cells[5].strip().strip("`").lower()
        if row_source == source and row_target == target and row_commit == commit:
            return {"branch": row_branch, "mode": mode, "category": row_category, "license": row_license}
    return None

def validate_catalog_authorization(catalog: str, request: dict[str, str], live_branch: str, license_id: str) -> dict[str, str]:
    authorization = catalog_authorization(catalog, request)
    if authorization is None:
        raise ValueError("The exact source, destination and pinned commit are not present together in the canonical catalog.")
    if authorization["branch"] != live_branch:
        raise ValueError(f"Catalog default branch mismatch: catalog={authorization['branch']} live={live_branch}. Refresh and review the catalog.")
    if authorization["mode"] != request["mode"]:
        raise ValueError(f"Acquisition mode mismatch: catalog={authorization['mode']} request={request['mode']}.")
    if authorization["category"] != request["category"]:
        raise ValueError("Request category does not exactly match the canonical catalog.")
    if authorization["mode"] == "mirror" and authorization["license"] != license_id:
        raise ValueError(f"GitHub SPDX metadata changed or differs from catalog: catalog={authorization['license']} live={license_id}.")
    return authorization

def catalog_line_authorizes(catalog: str, request: dict[str, str]) -> bool:
    return catalog_authorization(catalog, request) is not None

def write_outputs(path: str, values: dict[str, str]) -> None:
    with open(path, "a", encoding="utf-8") as output:
        for key, value in values.items():
            if not re.fullmatch(r"[A-Z_]+", key):
                raise ValueError("Invalid output key.")
            delimiter = f"ACQ_{uuid.uuid4().hex}"
            while delimiter in value:
                delimiter = f"ACQ_{uuid.uuid4().hex}"
            output.write(f"{key}<<{delimiter}\n{value}\n{delimiter}\n")

def api_json(token: str, path: str) -> dict[str, Any]:
    request = urllib.request.Request(f"{API}{path}", headers={
        "Accept": "application/vnd.github+json", "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "ULTRST-private-acquisition-controller",
    })
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read(4096).decode("utf-8", errors="replace")
        raise ValueError(f"GitHub API request failed ({exc.code}): {detail}") from None

def main() -> int:
    try:
        raw = os.environ.get("ISSUE_BODY", "")
        if not raw or len(raw.encode("utf-8")) > 12000:
            raise ValueError("Issue body is empty or exceeds 12 KB.")
        req = validate_request_shape(json.loads(raw))
        token = os.environ.get("GH_TOKEN", "")
        if not token:
            raise ValueError("CODING_REPO_TOKEN is unavailable.")
        source_meta = api_json(token, f"/repos/{req['source']}")
        if source_meta.get("archived") or source_meta.get("disabled"):
            raise ValueError("Archived or disabled upstream repositories cannot be acquired.")
        default_branch = source_meta.get("default_branch") or ""
        if not default_branch:
            raise ValueError("Upstream repository has no default branch.")
        license_id = (source_meta.get("license") or {}).get("spdx_id") or "NOASSERTION"
        branch_meta = api_json(token, f"/repos/{req['source']}/commits/{urllib.parse.quote(default_branch, safe='')}")
        branch_head = branch_meta.get("sha", "")
        if not re.fullmatch(r"[0-9a-f]{40}", branch_head):
            raise ValueError("Could not resolve the current upstream default-branch HEAD.")
        assert_exact_head(req["source_commit"], branch_head)
        if req["mode"] == "mirror" and license_id not in OPEN_SOURCE_IDS:
            raise ValueError(f"Cannot mirror code with missing or unrecognized open-source SPDX metadata: {license_id}.")
        catalog_meta = api_json(token, f"/repos/{WORKSPACE}/contents/{CATALOG_PATH}?ref=main")
        catalog_text = base64.b64decode(catalog_meta.get("content", "")).decode("utf-8")
        catalog_auth = validate_catalog_authorization(catalog_text, req, default_branch, license_id)
        write_outputs(os.environ["GITHUB_OUTPUT"], {
            "SOURCE": req["source"], "TARGET": req["target"], "CATEGORY": req["category"],
            "LICENSE_ID": license_id, "SOURCE_COMMIT": req["source_commit"],
            "SOURCE_DEFAULT_BRANCH": default_branch, "MODE": req["mode"],
            "APPROVAL_RECORD": req["approval_record"],
        })
        print(json.dumps({"source": req["source"], "target": req["target"], "source_default_branch": default_branch,
            "source_commit": req["source_commit"], "license_metadata": license_id, "mode": req["mode"],
            "catalog_authorization": "matched", "catalog_default_branch": catalog_auth["branch"],
            "catalog_mode": catalog_auth["mode"], "catalog_license": catalog_auth["license"]}, indent=2))
        return 0
    except (ValueError, KeyError, json.JSONDecodeError, urllib.error.URLError) as exc:
        print(f"Request rejected: {exc}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
