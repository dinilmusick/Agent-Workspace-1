#!/usr/bin/env python3
"""Create or safely resume a private independent mirror/reference repository."""
from __future__ import annotations
import base64, hashlib, json, os, pathlib, re, subprocess, sys, tempfile, time, urllib.error, urllib.parse, urllib.request
API = "https://api.github.com"
OWNER = "dinilmusick"

def repository_creation_stagger(target_name: str) -> int:
    return int(hashlib.sha256(target_name.encode("utf-8")).hexdigest()[:4], 16) % 120


def api(token, method, path, payload=None, allow_404=False):
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(API + path, data=data, method=method, headers={
        "Accept": "application/vnd.github+json", "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "ULTRST-private-acquisition-controller",
        **({"Content-Type": "application/json"} if data is not None else {}),
    })
    if method == "POST" and path == "/user/repos" and payload:
        stagger = repository_creation_stagger(str(payload.get("name", "")))
        if stagger:
            print(f"Staggering repository creation for {payload.get('name')} by {stagger}s to avoid secondary limits.", file=sys.stderr)
            time.sleep(stagger)
    for attempt in range(8):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                body = response.read()
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as exc:
            if allow_404 and exc.code == 404:
                return None
            detail = exc.read(4096).decode("utf-8", errors="replace")
            retryable = exc.code == 429 or (exc.code == 403 and "secondary rate limit" in detail.lower())
            if retryable and attempt < 7:
                retry_after = exc.headers.get("Retry-After")
                try:
                    delay = max(1, float(retry_after)) if retry_after else min(60 * (2 ** attempt), 900)
                except (TypeError, ValueError):
                    delay = min(60 * (2 ** attempt), 900)
                print(f"GitHub API secondary rate limit on {method} {path}; retry {attempt + 1}/7 in {delay:.0f}s.", file=sys.stderr)
                time.sleep(delay)
                continue
            raise RuntimeError(f"GitHub API {method} {path} failed ({exc.code}): {detail}") from None

def git(args, cwd=None, env=None, check=True):
    result = subprocess.run(["git", *args], cwd=cwd, env=env, text=True, capture_output=True)
    if check and result.returncode:
        detail = result.stderr
        if len(detail) > 6000:
            detail = detail[:2500] + "\\n...[middle omitted]...\\n" + detail[-3500:]
        raise RuntimeError(f"git {' '.join(args)} failed ({result.returncode}): {detail}")
    return result

def refs(repo):
    output = git(["for-each-ref", "--format=%(refname) %(objectname)"], cwd=repo).stdout
    return {line.split(" ", 1)[0]: line.split(" ", 1)[1] for line in output.splitlines() if line.strip()}

def archive_ref_name(ref, sha):
    digest = hashlib.sha256(ref.encode("utf-8")).hexdigest()[:16]
    return f"refs/ultrst-archive/{digest}/{sha}"

def preserve_and_reconcile_existing_refs(existing_refs, source_refs, source_repo, destination_repo):
    """Keep every previous destination tip reachable while reconciling refs to live upstream."""
    archived = []
    for ref, existing_sha in existing_refs.items():
        if ref.startswith("refs/ultrst-archive/"):
            if not re.fullmatch(r"refs/ultrst-archive/[0-9a-f]{16}/[0-9a-f]{40}", ref) or ref.rsplit("/", 1)[-1] != existing_sha:
                raise RuntimeError(f"Malformed ULTRST history-preservation ref {ref}; refusing to trust it.")
            archive_ref = ref
        else:
            source_sha = source_refs.get(ref)
            if source_sha == existing_sha:
                continue
            if source_sha is not None and ref.startswith("refs/heads/"):
                ancestry = git(["merge-base", "--is-ancestor", existing_sha, source_sha], cwd=source_repo, check=False)
                if ancestry.returncode == 0:
                    continue
            archive_ref = archive_ref_name(ref, existing_sha)

        current_source_refs = refs(source_repo)
        if current_source_refs.get(archive_ref) != existing_sha:
            fetch = git(["fetch", "--no-tags", str(destination_repo), f"{ref}:{archive_ref}"], cwd=source_repo, check=False)
            if fetch.returncode != 0:
                if git(["cat-file", "-e", existing_sha], cwd=source_repo, check=False).returncode != 0:
                    raise RuntimeError(f"Could not preserve previous destination history for {ref} at {existing_sha}: {fetch.stderr[-2000:]}")
                git(["update-ref", archive_ref, existing_sha], cwd=source_repo)
        if refs(source_repo).get(archive_ref) != existing_sha:
            raise RuntimeError(f"History preservation ref {archive_ref} does not point to the previous destination object.")
        source_refs[archive_ref] = existing_sha
        archived.append({"source_ref": ref, "archive_ref": archive_ref, "sha": existing_sha})
    return archived

def remote_refs(url, env):
    output = git(["ls-remote", "--refs", url], env=env).stdout
    return {
        line.split("\t", 1)[1]: line.split("\t", 1)[0]
        for line in output.splitlines()
        if "\t" in line and not line.split("\t", 1)[1].startswith(("refs/pull/", "refs/merge-queue/", "refs/remotes/", "refs/gh/"))
    }

def writable_refs(repo):
    return {
        ref: sha for ref, sha in refs(repo).items()
        if not ref.startswith(("refs/pull/", "refs/merge-queue/", "refs/remotes/", "refs/gh/"))
    }

def refspec_batches(ref_names, batch_size=100):
    if batch_size < 1:
        raise ValueError("batch_size must be positive")
    return [ref_names[index:index + batch_size] for index in range(0, len(ref_names), batch_size)]

def push_mirror_refs(repo, remote, env, source_refs, default_branch, stale_refs=(), batch_size=100):
    """Push every writable ref in bounded batches, then remove only refs whose tips were archived."""
    default_ref = f"refs/heads/{default_branch}"
    if default_ref not in source_refs:
        raise RuntimeError(f"Approved default branch ref {default_ref} is absent from the source mirror.")
    ordered_refs = [default_ref] + sorted(ref for ref in source_refs if ref != default_ref)
    batches = refspec_batches(ordered_refs, batch_size)
    print(f"Pushing {len(ordered_refs)} writable refs in {len(batches)} batches of at most {batch_size}.", file=sys.stderr)
    for batch in batches:
        refspecs = [f"+{ref}:{ref}" for ref in batch]
        git(["push", remote, *refspecs], cwd=repo, env=env)
    stale_refs = sorted(set(stale_refs))
    for batch in refspec_batches(stale_refs, batch_size):
        git(["push", remote, *[f":{ref}" for ref in batch]], cwd=repo, env=env)

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

def safe_provenance_migration(existing_description, source, mode, category, old_default_branch, new_default_branch, new_commit, comparison):
    match = re.fullmatch(r"ULTRST private (mirror|reference-only); upstream=([^;]+); commit=([0-9a-f]{40}); category=(.+)", existing_description or "")
    if not match:
        raise RuntimeError("Existing destination provenance marker is not a recognized ULTRST acquisition record.")
    old_mode, old_source, old_commit, old_category = match.groups()
    if old_mode != mode or old_source != source or old_category != category:
        raise RuntimeError("Existing destination provenance belongs to a different source, mode or category; refusing to repurpose it.")
    if mode != "mirror":
        raise RuntimeError("Automatic provenance pin migration is supported only for private source mirrors.")
    if old_default_branch != new_default_branch:
        raise RuntimeError("Existing destination default branch differs from the reviewed current upstream default branch.")
    if old_commit == new_commit:
        raise RuntimeError("Destination description differs despite an unchanged source pin; manual provenance review is required.")
    if comparison.get("status") != "ahead" or int(comparison.get("behind_by", -1)) != 0 or int(comparison.get("ahead_by", 0)) < 1:
        raise RuntimeError("Previous destination pin is not a strict ancestor of the reviewed current upstream pin; refusing provenance migration.")
    return old_commit

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
    provenance_migration_commit = None
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
        if destination_meta.get("default_branch") != source_branch:
            raise RuntimeError("Existing destination default branch differs from the reviewed source branch; refusing provenance migration.")
        old_marker = re.fullmatch(r"ULTRST private (mirror|reference-only); upstream=([^;]+); commit=([0-9a-f]{40}); category=(.+)", destination_meta.get("description") or "")
        if not old_marker:
            raise RuntimeError("Existing destination lacks a recognized ULTRST acquisition provenance marker; refusing to overwrite or repurpose it.")
        old_commit = old_marker.group(3)
        comparison = api(token, "GET", f"/repos/{source}/compare/{old_commit}...{source_commit}")
        provenance_migration_commit = safe_provenance_migration(
            destination_meta.get("description"), source, mode, category,
            destination_meta.get("default_branch"), source_branch, source_commit, comparison
        )
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
                if ref.startswith(("refs/pull/", "refs/merge-queue/", "refs/remotes/", "refs/gh/")):
                    git(["update-ref", "-d", ref], cwd=source_path)
            git(["remote", "remove", "origin"], cwd=source_path)
            source_refs = writable_refs(source_path)
            if any(ref.startswith("refs/ultrst-archive/") for ref in source_refs):
                raise RuntimeError("Upstream uses the reserved refs/ultrst-archive namespace; refusing to mix upstream refs with ULTRST history records.")
            if source_refs.get(f"refs/heads/{source_branch}") != source_commit:
                raise RuntimeError("Local mirror does not point its default branch at the approved source commit.")
            archived_history = []
            if existing_refs:
                existing_path = temp / "existing.git"
                git(["clone", "--mirror", target_url, str(existing_path)], env=git_env)
                git(["fsck", "--full", "--no-reflogs", "--connectivity-only"], cwd=existing_path)
                if provenance_migration_commit:
                    previous_default = writable_refs(existing_path).get(f"refs/heads/{source_branch}")
                    if previous_default != provenance_migration_commit:
                        raise RuntimeError("Existing destination default-branch ref does not match its previous provenance pin.")
                archived_history = preserve_and_reconcile_existing_refs(writable_refs(existing_path), source_refs, source_path, existing_path)
                source_refs = writable_refs(source_path)
            destination_refs_before = remote_refs(target_url, git_env)
            stale_destination_refs = sorted(set(destination_refs_before) - set(source_refs))
            preserved_deleted_refs = {item["source_ref"] for item in archived_history if item["source_ref"] not in source_refs}
            unexpected_refs = sorted(set(stale_destination_refs) - preserved_deleted_refs)
            if unexpected_refs:
                raise RuntimeError(f"Destination contains refs not represented in the reconciled source mirror or archived history; refusing to overwrite: {unexpected_refs[:20]}.")
            git(["remote", "add", "destination", target_url], cwd=source_path)
            push_mirror_refs(source_path, "destination", git_env, source_refs, source_branch, stale_destination_refs)
            git(["remote", "remove", "destination"], cwd=source_path)
            if git(["remote"], cwd=source_path).stdout.strip():
                raise RuntimeError("Temporary mirror retained a remote after push.")
            verify_path = temp / "destination-verify.git"
            git(["clone", "--mirror", target_url, str(verify_path)], env=git_env)
            for ref in list(refs(verify_path)):
                if ref.startswith(("refs/pull/", "refs/merge-queue/", "refs/remotes/", "refs/gh/")):
                    git(["update-ref", "-d", ref], cwd=verify_path)
            git(["fsck", "--full", "--no-reflogs", "--connectivity-only"], cwd=verify_path)
            final_refs = writable_refs(verify_path)
            if final_refs != source_refs:
                missing = sorted(set(source_refs) - set(final_refs))
                extra = sorted(set(final_refs) - set(source_refs))
                changed = sorted(ref for ref in set(source_refs) & set(final_refs) if source_refs[ref] != final_refs[ref])
                raise RuntimeError(f"Ref verification mismatch; missing={missing[:10]}, extra={extra[:10]}, changed={changed[:10]}.")
            source_objects = reachable_objects(source_path)
            destination_objects = reachable_objects(verify_path)
            if source_objects != destination_objects:
                missing_objects = sorted(source_objects - destination_objects)
                extra_objects = sorted(destination_objects - source_objects)
                raise RuntimeError(f"Reachable Git object/history verification mismatch; missing_count={len(missing_objects)}, extra_count={len(extra_objects)}, missing_sample={missing_objects[:10]}, extra_sample={extra_objects[:10]}.")
            repository_update = {"default_branch": source_branch}
            if provenance_migration_commit:
                repository_update["description"] = description
            api(token, "PATCH", f"/repos/{target}", repository_update)
            final_meta = api(token, "GET", f"/repos/{target}")
            if final_meta.get("private") is not True or final_meta.get("fork") is not False:
                raise RuntimeError("Final destination privacy/non-fork verification failed.")
            if final_meta.get("default_branch") != source_branch:
                raise RuntimeError("Final destination default branch metadata mismatch.")
            if final_refs.get(f"refs/heads/{source_branch}") != source_commit:
                raise RuntimeError("Destination default branch does not equal the pinned source commit.")
            migration_note = f" Provenance pin safely migrated from {provenance_migration_commit} to {source_commit} after verified ancestry." if provenance_migration_commit else ""
            result = f"Private independent mirror verified: all live writable refs, reachable history, pinned default branch, privacy and non-fork status match; preserved {len(archived_history)} previous ref tip(s) under refs/ultrst-archive.{migration_note}"
        archived_history = locals().get("archived_history", [])
        archive_details = "\n".join(
            f"- {item['source_ref']} -> {item['archive_ref']} ({item['sha']})" for item in archived_history
        ) or "- None"
        provenance_details = f"Previous approved pin migrated from {provenance_migration_commit} to {source_commit} after verified ancestry." if provenance_migration_commit else "No provenance pin migration was required."
        write_summary(f"## Acquisition result\n\n- Status: **success**\n- Destination: https://github.com/{target}\n- Upstream: https://github.com/{source}\n- Source commit: {source_commit}\n- Source default branch: {source_branch}\n- GitHub SPDX metadata: {license_id}\n- Acquisition mode: {mode}\n- Verification: {result}\n\n### Preserved previous ref tips\n\n{archive_details}\n\n### Provenance pin migration\n\n{provenance_details}\n\nPrivate research acquisition only. No commercial clearance is implied.")
        print(json.dumps({"destination": target, "source": source, "source_commit": source_commit, "mode": mode, "archived_history": archived_history, "provenance_migration_from": provenance_migration_commit, "result": result}, indent=2))

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Acquisition failed: {exc}", file=sys.stderr)
        write_summary(f"## Acquisition result\n\n- Status: **failed**\n- Reason: {exc}\n\nNo successful acquisition is claimed.")
        sys.exit(1)
