#!/usr/bin/env python3
"""Create or safely resume a private independent mirror/reference repository."""
from __future__ import annotations
import base64, json, os, pathlib, subprocess, sys, tempfile, urllib.error, urllib.parse, urllib.request
API = "https://api.github.com"
OWNER = "dinilmusick"

def api(token, method, path, payload=None, allow_404=False):
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(API + path, data=data, method=method, headers={
        "Accept": "application/vnd.github+json", "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "ULTRST-private-acquisition-controller",
        **({"Content-Type": "application/json"} if data is not None else {}),
    })
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        if allow_404 and exc.code == 404:
            return None
        detail = exc.read(4096).decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API {method} {path} failed ({exc.code}): {detail}") from None

def git(args, cwd=None, env=None, check=True):
    result = subprocess.run(["git", *args], cwd=cwd, env=env, text=True, capture_output=True)
    if check and result.returncode:
        raise RuntimeError(f"git {' '.join(args)} failed ({result.returncode}): {result.stderr[-4000:]}")
    return result

def refs(repo):
    output = git(["for-each-ref", "--format=%(refname) %(objectname)"], cwd=repo).stdout
    return {line.split(" ", 1)[0]: line.split(" ", 1)[1] for line in output.splitlines() if line.strip()}

def ensure_existing_refs_are_safe(existing_refs, source_refs, source_repo):
    """Allow exact refs or verified branch fast-forwards; reject divergence and repurposing."""
    for ref, existing_sha in existing_refs.items():
        source_sha = source_refs.get(ref)
        if source_sha is None:
            raise RuntimeError(f"Existing destination ref {ref} is absent upstream; refusing to overwrite or delete it.")
        if existing_sha == source_sha:
            continue
        if not ref.startswith("refs/heads/"):
            raise RuntimeError(f"Existing non-branch ref {ref} differs from upstream; refusing to overwrite it.")
        ancestry = git(["merge-base", "--is-ancestor", existing_sha, source_sha], cwd=source_repo, check=False)
        if ancestry.returncode != 0:
            raise RuntimeError(f"Existing branch {ref} is not an ancestor of the live upstream branch; divergent history is never overwritten.")

def remote_refs(url, env):
    output = git(["ls-remote", "--refs", url], env=env).stdout
    return {line.split("\t", 1)[1]: line.split("\t", 1)[0] for line in output.splitlines() if "\t" in line}

def reachable_objects(repo):
    output = git(["rev-list", "--objects", "--all"], cwd=repo).stdout
    return sorted({line.split(" ", 1)[0] for line in output.splitlines() if line.strip()})

def reference_readme(source, commit, branch, category, license_id):
    return f"""# Private project reference

**Category:** {category}

**Upstream repository:** https://github.com/{source}

**Pinned upstream revision:** {commit}

**Upstream default branch at acquisition:** {branch}

**GitHub license metadata:** {license_id}

**Acquisition mode:** reference-only. No upstream source files, assets, binaries, dependencies, or Git history were copied into this repository.

This private record preserves project identity and provenance for architectural study. Inspect upstream material at the pinned revision and follow the terms applicable there:

https://github.com/{source}/tree/{commit}

This record is not a license grant or permission to reproduce, distribute, deploy, or incorporate upstream material.
"""

def write_summary(text):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(text.rstrip() + "\n")

def main():
    token = os.environ["GH_TOKEN"]
    source = os.environ["SOURCE"]
    target_name = os.environ["TARGET"]
    target = f"{OWNER}/{target_name}"
    category = os.environ["CATEGORY"]
    source_commit = os.environ["SOURCE_COMMIT"]
    source_branch = os.environ["SOURCE_DEFAULT_BRANCH"]
    license_id = os.environ["LICENSE_ID"]
    mode = os.environ["MODE"]
    source_meta = api(token, "GET", f"/repos/{source}")
    if source_meta.get("archived") or source_meta.get("disabled"):
        raise RuntimeError("Upstream became archived or disabled after request validation.")
    live_license = (source_meta.get("license") or {}).get("spdx_id") or "NOASSERTION"
    if live_license != license_id:
        raise RuntimeError("Upstream license metadata changed after request validation.")
    live_branch = api(token, "GET", f"/repos/{source}/commits/{urllib.parse.quote(source_branch, safe='')}")
    if live_branch.get("sha") != source_commit:
        raise RuntimeError("Upstream default branch moved after validation; no destination changes were made.")
    description = f"ULTRST private {mode}; upstream={source}; commit={source_commit}; category={category}"
    if len(description) > 350:
        raise RuntimeError("Generated repository provenance description exceeds GitHub's limit.")
    destination_meta = api(token, "GET", f"/repos/{target}", allow_404=True)
    if destination_meta is None:
        try:
            destination_meta = api(token, "POST", "/user/repos", {
                "name": target_name, "private": True, "auto_init": False, "description": description,
            })
        except RuntimeError:
            destination_meta = api(token, "GET", f"/repos/{target}", allow_404=True)
            if destination_meta is None:
                raise
    if destination_meta.get("full_name", "").lower() != target.lower():
        raise RuntimeError("Destination owner/name mismatch.")
    if destination_meta.get("private") is not True or destination_meta.get("fork") is not False:
        raise RuntimeError("Destination must remain private and must not be a GitHub fork.")
    if destination_meta.get("description") != description:
        raise RuntimeError("Existing destination lacks the exact acquisition provenance marker; refusing to overwrite or repurpose it.")
    auth = base64.b64encode(f"x-access-token:{token}".encode()).decode()
    git_env = os.environ.copy()
    git_env.update({"GIT_TERMINAL_PROMPT": "0", "GIT_CONFIG_COUNT": "1",
        "GIT_CONFIG_KEY_0": "http.extraheader", "GIT_CONFIG_VALUE_0": f"AUTHORIZATION: basic {auth}"})
    target_url = f"https://github.com/{target}.git"
    with tempfile.TemporaryDirectory(prefix="ultrst-acquisition-") as temp_dir:
        temp = pathlib.Path(temp_dir)
        existing_refs = remote_refs(target_url, git_env)
        if mode == "reference-only":
            expected = reference_readme(source, source_commit, source_branch, category, license_id)
            if existing_refs:
                if set(existing_refs) != {"refs/heads/main"}:
                    raise RuntimeError("Existing reference-only destination has unexpected refs; refusing to overwrite.")
                verify_path = temp / "reference-verify.git"
                git(["clone", "--mirror", target_url, str(verify_path)], env=git_env)
                tree = git(["ls-tree", "-r", "--name-only", "refs/heads/main"], cwd=verify_path).stdout.splitlines()
                body = git(["show", "refs/heads/main:README.md"], cwd=verify_path).stdout
                commit_count = int(git(["rev-list", "--count", "refs/heads/main"], cwd=verify_path).stdout.strip())
                if tree != ["README.md"] or body != expected or commit_count != 1:
                    raise RuntimeError("Existing reference-only repository is not the exact single-commit provenance-only record.")
                if destination_meta.get("default_branch") != "main":
                    raise RuntimeError("Existing reference-only repository default branch is not main.")
                result = "Existing reference-only record independently matched README-only contents."
            else:
                work = temp / "reference"
                work.mkdir()
                git(["init", "-b", "main"], cwd=work)
                git(["config", "user.name", "ULTRST Private Reference Catalog"], cwd=work)
                git(["config", "user.email", "reference-catalog@users.noreply.github.com"], cwd=work)
                (work / "README.md").write_text(expected, encoding="utf-8")
                git(["add", "README.md"], cwd=work)
                git(["commit", "-m", "docs: record private upstream project reference"], cwd=work)
                git(["remote", "add", "destination", target_url], cwd=work)
                git(["push", "destination", "HEAD:refs/heads/main"], cwd=work, env=git_env)
                git(["remote", "remove", "destination"], cwd=work)
                result = "Created provenance-only reference record; no upstream code/assets/history copied."
            api(token, "PATCH", f"/repos/{target}", {"default_branch": "main"})
            verify_path = temp / "reference-final.git"
            git(["clone", "--mirror", target_url, str(verify_path)], env=git_env)
            final_refs = refs(verify_path)
            tree = git(["ls-tree", "-r", "--name-only", "refs/heads/main"], cwd=verify_path).stdout.splitlines()
            body = git(["show", "refs/heads/main:README.md"], cwd=verify_path).stdout
            commit_count = int(git(["rev-list", "--count", "refs/heads/main"], cwd=verify_path).stdout.strip())
            if set(final_refs) != {"refs/heads/main"} or tree != ["README.md"] or body != expected or commit_count != 1:
                raise RuntimeError("Final reference-only verification failed: destination must contain exactly one commit and README.md.")
            final_meta = api(token, "GET", f"/repos/{target}")
            if final_meta.get("private") is not True or final_meta.get("fork") is not False or final_meta.get("default_branch") != "main":
                raise RuntimeError("Final reference-only repository metadata verification failed.")
        else:
            source_path = temp / "source.git"
            git(["clone", "--mirror", f"https://github.com/{source}.git", str(source_path)])
            git(["cat-file", "-e", f"{source_commit}^{{commit}}"], cwd=source_path)
            for ref in list(refs(source_path)):
                if ref.startswith(("refs/pull/", "refs/merge-queue/", "refs/remotes/")):
                    git(["update-ref", "-d", ref], cwd=source_path)
            git(["remote", "remove", "origin"], cwd=source_path)
            source_refs = refs(source_path)
            if source_refs.get(f"refs/heads/{source_branch}") != source_commit:
                raise RuntimeError("Local mirror does not point its default branch at the approved source commit.")
            ensure_existing_refs_are_safe(existing_refs, source_refs, source_path)
            if existing_refs:
                existing_path = temp / "existing.git"
                git(["clone", "--mirror", target_url, str(existing_path)], env=git_env)
                git(["fsck", "--full", "--no-reflogs", "--connectivity-only"], cwd=existing_path)
                ensure_existing_refs_are_safe(refs(existing_path), source_refs, source_path)
            git(["remote", "add", "destination", target_url], cwd=source_path)
            git(["push", "--mirror", "destination"], cwd=source_path, env=git_env)
            git(["remote", "remove", "destination"], cwd=source_path)
            if git(["remote"], cwd=source_path).stdout.strip():
                raise RuntimeError("Temporary mirror retained a remote after push.")
            verify_path = temp / "destination-verify.git"
            git(["clone", "--mirror", target_url, str(verify_path)], env=git_env)
            git(["fsck", "--full", "--no-reflogs", "--connectivity-only"], cwd=verify_path)
            final_refs = refs(verify_path)
            if final_refs != source_refs:
                missing = sorted(set(source_refs) - set(final_refs))
                extra = sorted(set(final_refs) - set(source_refs))
                changed = sorted(ref for ref in set(source_refs) & set(final_refs) if source_refs[ref] != final_refs[ref])
                raise RuntimeError(f"Ref verification mismatch; missing={missing[:10]}, extra={extra[:10]}, changed={changed[:10]}.")
            if reachable_objects(source_path) != reachable_objects(verify_path):
                raise RuntimeError("Reachable Git object/history verification mismatch.")
            api(token, "PATCH", f"/repos/{target}", {"default_branch": source_branch})
            final_meta = api(token, "GET", f"/repos/{target}")
            if final_meta.get("private") is not True or final_meta.get("fork") is not False:
                raise RuntimeError("Final destination privacy/non-fork verification failed.")
            if final_meta.get("default_branch") != source_branch:
                raise RuntimeError("Final destination default branch metadata mismatch.")
            if final_refs.get(f"refs/heads/{source_branch}") != source_commit:
                raise RuntimeError("Destination default branch does not equal the pinned source commit.")
            result = "Private independent mirror verified: all writable refs, reachable history, pinned default branch, privacy and non-fork status match."
        write_summary(f"## Acquisition result\n\n- Status: **success**\n- Destination: https://github.com/{target}\n- Upstream: https://github.com/{source}\n- Source commit: {source_commit}\n- Source default branch: {source_branch}\n- GitHub SPDX metadata: {license_id}\n- Acquisition mode: {mode}\n- Verification: {result}\n\nPrivate research acquisition only. No commercial clearance is implied.")
        print(json.dumps({"destination": target, "source": source, "source_commit": source_commit, "mode": mode, "result": result}, indent=2))

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Acquisition failed: {exc}", file=sys.stderr)
        write_summary(f"## Acquisition result\n\n- Status: **failed**\n- Reason: {exc}\n\nNo successful acquisition is claimed.")
        sys.exit(1)
