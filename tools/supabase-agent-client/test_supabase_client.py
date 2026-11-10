import json
import os
import unittest
from unittest.mock import patch

from supabase_client import SupabaseAgentClient, SupabaseClientError, SupabaseConfig


class FakeResponse:
    def __init__(self, payload):
        self.payload = json.dumps(payload).encode()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self):
        return self.payload


class SupabaseAgentClientTests(unittest.TestCase):
    def test_config_prefers_service_role_key_without_logging_it(self):
        with patch.dict(
            os.environ,
            {
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_SERVICE_ROLE_KEY": "secret-service-role",
                "SUPABASE_ANON_KEY": "anon",
            },
            clear=True,
        ):
            config = SupabaseConfig.from_environment()
        self.assertEqual(config.url, "https://example.supabase.co")
        self.assertEqual(config.key, "secret-service-role")
        self.assertNotIn("secret-service-role", repr(config))

    def test_config_requires_credentials(self):
        with patch.dict(
            os.environ,
            {"SUPABASE_URL": "https://example.supabase.co"},
            clear=True,
        ):
            with self.assertRaisesRegex(SupabaseClientError, "key"):
                SupabaseConfig.from_environment()

    @patch("supabase_client.urlopen")
    def test_rpc_sends_authenticated_json_request(self, mock_urlopen):
        mock_urlopen.return_value = FakeResponse({"ok": True})
        client = SupabaseAgentClient(
            SupabaseConfig("https://example.supabase.co", "test-key")
        )

        result = client.rpc("goal_ledger_overview", {"p_goal_id": None})

        request = mock_urlopen.call_args.args[0]
        self.assertEqual(result, {"ok": True})
        self.assertEqual(request.full_url, "https://example.supabase.co/rest/v1/rpc/goal_ledger_overview")
        self.assertEqual(request.get_header("Apikey"), "test-key")
        self.assertEqual(request.get_header("Authorization"), "Bearer test-key")
        self.assertEqual(json.loads(request.data), {"p_goal_id": None})

    @patch("supabase_client.urlopen")
    def test_table_select_encodes_filters(self, mock_urlopen):
        mock_urlopen.return_value = FakeResponse([])
        client = SupabaseAgentClient(
            SupabaseConfig("https://example.supabase.co", "test-key")
        )

        result = client.table(
            "skills",
            filters={"slug": "eq.coding", "limit": "1"},
        )

        request = mock_urlopen.call_args.args[0]
        self.assertEqual(result, [])
        self.assertIn("select=%2A", request.full_url)
        self.assertIn("slug=eq.coding", request.full_url)
        self.assertIn("limit=1", request.full_url)

    def test_update_and_delete_require_filters(self):
        client = SupabaseAgentClient(
            SupabaseConfig("https://example.supabase.co", "test-key")
        )
        with self.assertRaisesRegex(SupabaseClientError, "filter"):
            client.table("skills", operation="update", rows={"x": 1})
        with self.assertRaisesRegex(SupabaseClientError, "filter"):
            client.table("skills", operation="delete")

    def test_ledger_allows_only_canonical_rpc_surface(self):
        client = SupabaseAgentClient(
            SupabaseConfig("https://example.supabase.co", "test-key")
        )
        with patch.object(client, "rpc", return_value={"ok": True}) as rpc:
            self.assertEqual(
                client.ledger("goal_ledger_overview", {"p_goal_id": None}),
                {"ok": True},
            )
            with self.assertRaisesRegex(SupabaseClientError, "Unsupported ledger"):
                client.ledger("arbitrary_sql", {})

    @patch("supabase_client.urlopen")
    def test_skills_use_postgrest(self, mock_urlopen):
        mock_urlopen.return_value = FakeResponse([{"slug": "coding-router"}])
        client = SupabaseAgentClient(
            SupabaseConfig("https://example.supabase.co", "test-key")
        )
        self.assertEqual(client.skills(search="coding"), [{"slug": "coding-router"}])
        request = mock_urlopen.call_args.args[0]
        self.assertIn("/rest/v1/skills?", request.full_url)
        self.assertIn("ilike", request.full_url)


if __name__ == "__main__":
    unittest.main()
