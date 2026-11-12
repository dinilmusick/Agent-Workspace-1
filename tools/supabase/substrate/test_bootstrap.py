import os
import unittest
from pathlib import Path
from unittest.mock import patch

import bootstrap


class SubstrateToolTests(unittest.TestCase):
    def test_plan_uses_versioned_repo_assets(self):
        plan = bootstrap.plan()
        self.assertEqual(plan["source"], "supabase")
        self.assertGreater(plan["migration_count"], 0)
        self.assertTrue(plan["seed_bytes"] > 0)

    def test_project_ref_is_required(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(bootstrap.SubstrateError, "project ref"):
                bootstrap.project_ref(None)

    def test_remote_push_requires_cli_credentials(self):
        with patch.dict(os.environ, {"SUPABASE_PROJECT_ID": "example-ref"}, clear=True):
            with self.assertRaisesRegex(bootstrap.SubstrateError, "SUPABASE_ACCESS_TOKEN"):
                bootstrap.require_remote_credentials()

    def test_no_secret_values_are_in_repo_paths(self):
        root = Path(bootstrap.ROOT)
        for path in root.glob("**/*"):
            if path.is_file() and ".git" not in path.parts:
                text = path.read_text(errors="ignore")
                self.assertNotIn("service_role_key", text.lower())


if __name__ == "__main__":
    unittest.main()
