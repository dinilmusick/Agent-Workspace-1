#!/usr/bin/env python3
"""Primary GitHub repository lifecycle tool for AgentGPT.

Operations: create, rename, delete, verify.
Authentication: GITHUB_TOKEN or GH_TOKEN only.
"""

from __future__ import annotations
import argparse, json, os
from urllib import error, request

API_ROOT = "https://api.github.com"

def api(path, token, method="GET", payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    req = request.Request(API_ROOT + path, data=body, method=method, headers={
        "Accept":"application/vnd.github+json",
        "Authorization":f"Bearer {token}",
        "X-GitHub-Api-Version":"2022-11-28",
        "Content-Type":"application/json",
        "User-Agent":"atax-github-repository-tool",
    })
    try:
        with request.urlopen(req, timeout=30) as response:
            if response.status == 204: return None
            return json.load(response)
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        try: message = json.loads(detail).get("message", detail)
        except json.JSONDecodeError: message = detail
        raise RuntimeError(f"GitHub API {method} {path} failed: {message}") from exc

def get_token():
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token: raise SystemExit("Missing GITHUB_TOKEN or GH_TOKEN; refusing to mutate GitHub.")
    return token

def repo(value):
    if value.count("/") != 1 or any(not p for p in value.split("/")):
        raise SystemExit("repository must be owner/name")
    return value

def main():
    p=argparse.ArgumentParser()
    s=p.add_subparsers(dest="op", required=True)
    c=s.add_parser("create"); c.add_argument("--name",required=True); c.add_argument("--description",default=""); c.add_argument("--visibility",choices=("public","private"),default="public")
    r=s.add_parser("rename"); r.add_argument("--repository",required=True); r.add_argument("--new-name",required=True)
    d=s.add_parser("delete"); d.add_argument("--repository",required=True)
    v=s.add_parser("verify"); v.add_argument("--repository",required=True)
    a=p.parse_args(); tok=get_token()
    if a.op=="create":
        result=api("/user/repos",tok,"POST",{"name":a.name,"description":a.description,"private":a.visibility=="private","auto_init":True})
        full=result["full_name"]; check=api("/repos/"+full,tok)
        if check["private"] != (a.visibility=="private"): raise SystemExit("creation verification failed")
        print(json.dumps({"operation":"create","repository":full,"url":check["html_url"],"verified":True})); return 0
    target=repo(a.repository)
    if a.op=="verify":
        result=api("/repos/"+target,tok)
        print(json.dumps({"operation":"verify","repository":result["full_name"],"url":result["html_url"],"private":result["private"],"default_branch":result.get("default_branch"),"verified":True})); return 0
    if a.op=="rename":
        result=api("/repos/"+target,tok,"PATCH",{"name":a.new_name})
        new_repo=result["full_name"]; check=api("/repos/"+new_repo,tok)
        if check["name"] != a.new_name: raise SystemExit("rename verification failed")
        print(json.dumps({"operation":"rename","from":target,"repository":new_repo,"url":check["html_url"],"verified":True})); return 0
    if a.op=="delete":
        api("/repos/"+target,tok,"DELETE")
        try: api("/repos/"+target,tok)
        except RuntimeError as exc:
            if "Not Found" in str(exc) or "not found" in str(exc).lower():
                print(json.dumps({"operation":"delete","repository":target,"verified":True,"exists":False})); return 0
            raise
        raise SystemExit("delete verification failed: repository still exists")

if __name__=="__main__": raise SystemExit(main())
