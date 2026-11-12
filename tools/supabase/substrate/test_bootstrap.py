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

    def test_substrate_assets_do_not_embed_secret_values(self):
        substrate = Path(bootstrap.__file__).resolve().parent
        for path in substrate.rglob("*"):
            if path.is_file():
                text = path.read_text(errors="ignore")
                self.assertNotIn("sb_secret_", text)
                self.assertNotIn("sbp_", text)




if __name__ == "__main__":
    unittest.main()
