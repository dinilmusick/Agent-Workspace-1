#!/usr/bin/env python3
"""Minimal Supabase PostgREST/RPC client for connector-less agent runtimes."""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


class SupabaseClientError(RuntimeError):
    """A safe, structured client error without credential leakage."""


@dataclass(frozen=True)
class SupabaseConfig:
    url: str
    key: str

    @classmethod
    def from_environment(cls) -> "SupabaseConfig":
        url = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
        key = (
            os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
            or os.environ.get("SUPABASE_ANON_KEY", "").strip()
        )
        if not url:
            raise SupabaseClientError("SUPABASE_URL is required")
        if not key:
            raise SupabaseClientError(
                "SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY is required"
            )
        if not url.startswith(("https://", "http://")):
            raise SupabaseClientError("SUPABASE_URL must be an HTTP(S) URL")
        return cls(url=url, key=key)


class SupabaseAgentClient:
    """HTTP client with semantic AgentGPT ledger and skill operations."""

    def __init__(self, config: SupabaseConfig, timeout: float = 30.0):
        self.config = config
        self.timeout = timeout

    @classmethod
    def from_environment(cls, timeout: float = 30.0) -> "SupabaseAgentClient":
        return cls(SupabaseConfig.from_environment(), timeout=timeout)

    def _request(
        self,
        method: str,
        path: str,
        *,
        query: dict[str, str] | None = None,
        body: Any = None,
        prefer: str | None = None,
    ) -> Any:
        url = f"{self.config.url}{path}"
        if query:
            url = f"{url}?{urlencode(query)}"
        headers = {
            "apikey": self.config.key,
            "Authorization": f"Bearer {self.config.key}",
            "Accept": "application/json",
        }
        if body is not None:
            headers["Content-Type"] = "application/json"
        if prefer:
            headers["Prefer"] = prefer

        payload = None if body is None else json.dumps(body).encode("utf-8")
        request = Request(url, data=payload, headers=headers, method=method)
        try:
            with urlopen(request, timeout=self.timeout) as response:
                raw = response.read().decode("utf-8")
        except HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise SupabaseClientError(
                f"Supabase request failed ({exc.code}): {detail[:1000]}"
            ) from exc
        except URLError as exc:
            raise SupabaseClientError(f"Supabase connection failed: {exc.reason}") from exc

        if not raw:
            return None
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw

    def table(
        self,
        table: str,
        *,
        operation: str = "select",
        select: str = "*",
        filters: dict[str, str] | None = None,
        rows: Any = None,
    ) -> Any:
        if not table or not table.replace("_", "").isalnum():
            raise SupabaseClientError("Invalid table name")
        path = f"/rest/v1/{quote(table, safe='')}"
        filters = filters or {}

        if operation == "select":
            query = {"select": select, **filters}
            return self._request("GET", path, query=query)

        if operation == "insert":
            if rows is None:
                raise SupabaseClientError("insert requires rows")
            return self._request(
                "POST",
                path,
                body=rows,
                prefer="return=representation",
            )

        if operation == "update":
            if rows is None:
                raise SupabaseClientError("update requires rows")
            if not filters:
                raise SupabaseClientError("update requires at least one filter")
            return self._request(
                "PATCH",
                path,
                query=filters,
                body=rows,
                prefer="return=representation",
            )

        if operation == "delete":
            if not filters:
                raise SupabaseClientError("delete requires at least one filter")
            return self._request(
                "DELETE",
                path,
                query=filters,
                prefer="return=representation",
            )

        raise SupabaseClientError(f"Unsupported table operation: {operation}")

    def rpc(self, name: str, args: dict[str, Any] | None = None) -> Any:
        if not name or not name.replace("_", "").isalnum():
            raise SupabaseClientError("Invalid RPC name")
        return self._request(
            "POST",
            f"/rest/v1/rpc/{quote(name, safe='')}",
            body=args or {},
        )

    def ledger(self, action: str, args: dict[str, Any] | None = None) -> Any:
        """Call a canonical AgentGPT ledger RPC by name."""
        allowed = {
            "goal_ledger_overview",
            "goal_ledger_resume_by_key",
            "goal_ledger_list_unfinished",
            "goal_ledger_create_hierarchical",
            "goal_ledger_claim_task_by_key",
            "goal_ledger_record_loop_iteration",
            "task_ledger_record_loop_iteration",
        }
        if action not in allowed:
            raise SupabaseClientError(f"Unsupported ledger action: {action}")
        return self.rpc(action, args or {})

    def skills_list(self, *, search: str | None = None) -> Any:
        """Read the canonical public.skills registry through PostgREST."""
        filters = {"select": "*", "order": "slug.asc"}
        if search:
            filters["slug"] = f"ilike.*{search}*"
        return self.table("skills", operation="select", select=filters.pop("select"), filters=filters)

    def skills(self, *, search: str | None = None) -> Any:
        return self.skills_list(search=search)

    def skill_versions(self, *, skill_id: str | None = None) -> Any:
        filters = {"order": "created_at.desc"}
        if skill_id:
            filters["skill_id"] = f"eq.{skill_id}"
        return self.table("skill_versions", operation="select", select="*", filters=filters)

    def skill_tools(self, *, slug: str | None = None) -> Any:
        filters = {"order": "slug.asc"}
        if slug:
            filters["slug"] = f"eq.{slug}"
        return self.table("skill_tools", operation="select", select="*", filters=filters)

    def skill_tool_links(self, *, skill_id: str | None = None) -> Any:
        filters = {"order": "skill_id.asc"}
        if skill_id:
            filters["skill_id"] = f"eq.{skill_id}"
        return self.table("skill_tool_links", operation="select", select="*", filters=filters)


def _json_arg(value: str) -> dict[str, Any]:
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as exc:
        raise SupabaseClientError(f"Invalid JSON: {exc}") from exc
    if not isinstance(parsed, dict):
        raise SupabaseClientError("JSON arguments must be an object")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Connector-less AgentGPT Supabase client")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("overview")
    sub.add_parser("unfinished")

    resume = sub.add_parser("resume")
    resume.add_argument("--goal-key", required=True)

    claim = sub.add_parser("claim-task")
    claim.add_argument("--task-key", required=True)
    claim.add_argument("--agent-id", required=True)
    claim.add_argument("--lease-minutes", type=int, default=60)

    skills = sub.add_parser("skills")
    skills.add_argument("--search")

    rpc = sub.add_parser("rpc")
    rpc.add_argument("--name", required=True)
    rpc.add_argument("--args", default="{}")

    table = sub.add_parser("table")
    table.add_argument("--table", required=True)
    table.add_argument("--operation", choices=["select", "insert", "update", "delete"], default="select")
    table.add_argument("--select", default="*")
    table.add_argument("--filters", default="{}")
    table.add_argument("--rows", default=None)

    return parser


def run_cli(argv: list[str]) -> Any:
    args = build_parser().parse_args(argv)
    client = SupabaseAgentClient.from_environment()

    if args.command == "overview":
        return client.ledger("goal_ledger_overview", {"p_goal_id": None})
    if args.command == "unfinished":
        return client.ledger("goal_ledger_list_unfinished", {})
    if args.command == "resume":
        return client.ledger("goal_ledger_resume_by_key", {"p_goal_key": args.goal_key})
    if args.command == "claim-task":
        return client.ledger(
            "goal_ledger_claim_task_by_key",
            {
                "p_task_key": args.task_key,
                "p_agent_id": args.agent_id,
                "p_lease_minutes": max(60, args.lease_minutes),
            },
        )
    if args.command == "skills":
        return client.skills(search=args.search)
    if args.command == "rpc":
        return client.rpc(args.name, _json_arg(args.args))
    return client.table(
        args.table,
        operation=args.operation,
        select=args.select,
        filters=_json_arg(args.filters),
        rows=None if args.rows is None else json.loads(args.rows),
    )


def main(argv: list[str] | None = None) -> int:
    try:
        result = run_cli(argv or sys.argv[1:])
        print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
        return 0
    except SupabaseClientError as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
