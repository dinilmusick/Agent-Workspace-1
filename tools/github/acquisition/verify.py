#!/usr/bin/env python3
"""Read-only second-pass verifier for a completed private acquisition."""
from __future__ import annotations
import base64, json, os, pathlib, subprocess, sys, tempfile, urllib.error, urllib.parse, urllib.request
from acquire import is_writable_ref, reference_readme

API = "https://api.github.com"
OWNER = "dinilmusick"

def api_get(token, path):
    request = urllib.request.Request(API + path, headers={
        "Accept":"application/vnd.github+json","Authorization":f"Bearer {token}",
        "X-GitHub-Api-Version":"2022-11-28","User-Agent":"ULTRST-read-only-acquisition-verifier"})
    try:
        with urllib.request.urlopen(request,timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail=exc.read(4096).decode("utf-8",errors="replace")
        raise RuntimeError(f"Read-only GitHub API GET failed ({exc.code}): {detail}") from None

def git(args,cwd=None,env=None):
    result=subprocess.run(["git",*args],cwd=cwd,env=env,text=True,capture_output=True)
    if result.returncode:
        raise RuntimeError(f"Read-only git {' '.join(args)} failed ({result.returncode}): {result.stderr[-4000:]}")
    return result

def refs(repo):
    output=git(["for-each-ref","--format=%(refname) %(objectname)"],cwd=repo).stdout
    return {line.split(" ",1)[0]:line.split(" ",1)[1] for line in output.splitlines() if line.strip()}

def writable_refs(repo):
    return {ref:sha for ref,sha in refs(repo).items() if is_writable_ref(ref)}

def objects(repo):
    output=git(["rev-list","--objects","--all"],cwd=repo).stdout
    return sorted({line.split(" ",1)[0] for line in output.splitlines() if line.strip()})

def summary(message):
    path=os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path,"a",encoding="utf-8") as handle: handle.write(message.rstrip()+"\n")

def main():
    token=os.environ["GH_TOKEN"]
    source=os.environ["SOURCE"]
    target=f"{OWNER}/{os.environ['TARGET']}"
    commit=os.environ["SOURCE_COMMIT"]
    branch=os.environ["SOURCE_DEFAULT_BRANCH"]
    category=os.environ["CATEGORY"]
    license_id=os.environ["LICENSE_ID"]
    mode=os.environ["MODE"]
    source_meta=api_get(token,f"/repos/{source}")
    if source_meta.get("archived") or source_meta.get("disabled"):
        raise RuntimeError("Upstream is archived or disabled.")
    live_license=(source_meta.get("license") or {}).get("spdx_id") or "NOASSERTION"
    if live_license!=license_id:
        raise RuntimeError("Upstream license metadata changed after request validation.")
    live=api_get(token,f"/repos/{source}/commits/{urllib.parse.quote(branch,safe='')}")
    if live.get("sha")!=commit:
        raise RuntimeError("Source default branch moved after acquisition.")
    target_meta=api_get(token,f"/repos/{target}")
    expected_description=f"ULTRST private {mode}; upstream={source}; commit={commit}; category={category}"
    if target_meta.get("private") is not True or target_meta.get("fork") is not False:
        raise RuntimeError("Destination is not private and independent (non-fork).")
    if target_meta.get("description")!=expected_description:
        raise RuntimeError("Destination provenance description does not exactly match the requested source, commit, mode and category.")
    expected_branch="main" if mode=="reference-only" else branch
    if target_meta.get("default_branch")!=expected_branch:
        raise RuntimeError("Destination default branch metadata mismatch.")
    auth=base64.b64encode(f"x-access-token:{token}".encode()).decode()
    git_env=os.environ.copy()
    git_env.update({"GIT_TERMINAL_PROMPT":"0","GIT_CONFIG_COUNT":"1","GIT_CONFIG_KEY_0":"http.extraheader",
        "GIT_CONFIG_VALUE_0":f"AUTHORIZATION: basic {auth}"})
    target_url=f"https://github.com/{target}.git"
    with tempfile.TemporaryDirectory(prefix="ultrst-readonly-verify-") as tmp:
        root=pathlib.Path(tmp)
        destination=root/"destination.git"
        git(["clone","--mirror",target_url,str(destination)],env=git_env)
        for ref in list(refs(destination)):
            if not is_writable_ref(ref):
                git(["update-ref","-d",ref],cwd=destination)
        git(["fsck","--full","--no-reflogs","--connectivity-only"],cwd=destination)
        destination_refs=writable_refs(destination)
        if mode=="reference-only":
            expected=reference_readme(source,commit,branch,category,license_id)
            tree=git(["ls-tree","-r","--name-only","refs/heads/main"],cwd=destination).stdout.splitlines()
            body=git(["show","refs/heads/main:README.md"],cwd=destination).stdout
            commit_count=int(git(["rev-list","--count","refs/heads/main"],cwd=destination).stdout.strip())
            if set(destination_refs)!={"refs/heads/main"} or tree!=["README.md"] or body!=expected or commit_count!=1:
                raise RuntimeError("Reference-only destination is not exactly one provenance README commit.")
            result="Read-only verifier confirmed private/non-fork metadata, exact provenance and README-only contents."
        else:
            source_path=root/"source.git"
            git(["clone","--mirror",f"https://github.com/{source}.git",str(source_path)])
            for ref in list(refs(source_path)):
                if ref.startswith(("refs/pull/","refs/merge-queue/","refs/remotes/","refs/gh/")):
                    git(["update-ref","-d",ref],cwd=source_path)
            git(["remote","remove","origin"],cwd=source_path)
            if git(["remote"],cwd=source_path).stdout.strip():
                raise RuntimeError("Read-only source comparison clone retained a remote.")
            source_refs=writable_refs(source_path)
            if any(ref.startswith("refs/ultrst-archive/") for ref in source_refs):
                raise RuntimeError("Upstream uses the reserved refs/ultrst-archive namespace.")
            if source_refs.get(f"refs/heads/{branch}")!=commit:
                raise RuntimeError("Upstream source clone does not resolve to the approved default-branch SHA.")
            archive_refs={ref:sha for ref,sha in destination_refs.items() if ref.startswith("refs/ultrst-archive/")}
            upstream_destination_refs={ref:sha for ref,sha in destination_refs.items() if not ref.startswith("refs/ultrst-archive/")}
            if upstream_destination_refs!=source_refs:
                missing=sorted(set(source_refs)-set(upstream_destination_refs))
                extra=sorted(set(upstream_destination_refs)-set(source_refs))
                changed=sorted(ref for ref in set(source_refs)&set(upstream_destination_refs) if source_refs[ref]!=upstream_destination_refs[ref])
                raise RuntimeError(f"Independent read-only verifier found upstream ref mismatches; missing={missing[:10]}, extra={extra[:10]}, changed={changed[:10]}.")
            import re
            for archive_ref,archive_sha in archive_refs.items():
                if not re.fullmatch(r"refs/ultrst-archive/[0-9a-f]{16}/[0-9a-f]{40}",archive_ref) or archive_ref.rsplit("/",1)[-1]!=archive_sha:
                    raise RuntimeError(f"Malformed history-preservation ref {archive_ref}.")
                object_type=git(["cat-file","-t",archive_sha],cwd=destination).stdout.strip()
                if object_type not in {"commit","tag"}:
                    raise RuntimeError(f"History-preservation ref {archive_ref} does not point to a commit or tag object.")
            source_objects=set(objects(source_path))
            destination_objects=set(objects(destination))
            if not source_objects.issubset(destination_objects):
                missing_objects=sorted(source_objects-destination_objects)
                raise RuntimeError(f"Independent read-only verifier found upstream objects missing from destination; count={len(missing_objects)}, sample={missing_objects[:10]}.")
            result=f"Read-only verifier matched every live upstream writable ref and reachable object ID, plus exact default branch, pin, private/non-fork metadata and provenance; preserved {len(archive_refs)} prior ref tip(s) in refs/ultrst-archive/."
    archive_details = "\n".join(f"- {ref} ({sha})" for ref,sha in sorted(archive_refs.items())) if mode != "reference-only" else "- None"
    summary(f"## Independent read-only acquisition verification\n\n- Status: **passed**\n- Destination: https://github.com/{target}\n- Upstream: https://github.com/{source}\n- Pinned commit: {commit}\n- Mode: {mode}\n- Result: {result}\n\n### Preserved history refs\n\n{archive_details}\n\nThis confirms acquisition only; commercial clearance remains separate.")
    print(json.dumps({"destination":target,"source":source,"commit":commit,"mode":mode,"verification":"passed","result":result},indent=2))

if __name__=="__main__":
    try: main()
    except Exception as exc:
        print(f"Independent verification failed: {exc}",file=sys.stderr)
        summary(f"## Independent read-only acquisition verification\n\n- Status: **failed**\n- Reason: {exc}")
        sys.exit(1)
