import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import platform_adapters as adapters

class PlatformAdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.out = self.root / "artifacts"
        self.out.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def test_cloudflare_requires_current_workers_vitest_plugin(self):
        (self.root / "wrangler.jsonc").write_text('{"name":"worker"}')
        (self.root / "package.json").write_text(json.dumps({"devDependencies": {"@cloudflare/vitest-pool-workers": "0.8.0"}}))
        (self.root / "vitest.config.ts").write_text("export default {};")
        with self.assertRaisesRegex(adapters.AdapterError, "vitest-plugin"):
            adapters.run_cloudflare(self.root, self.out)

    def test_cloudflare_executes_vitest_with_current_plugin(self):
        (self.root / "wrangler.jsonc").write_text('{"name":"worker"}')
        (self.root / "package.json").write_text(json.dumps({"devDependencies": {"@cloudflare/vitest-plugin": "1.4.12"}}))
        (self.root / "vitest.config.ts").write_text('import { cloudflareTest } from "@cloudflare/vitest-plugin"; export default { plugins: [cloudflareTest()] };')
        with patch.object(adapters, "run") as command:
            result = adapters.run_cloudflare(self.root, self.out)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(command.call_args.args[0][-1], "run")

    def test_vercel_preview_url_requires_vercel_app_https(self):
        self.assertEqual(adapters.validate_preview_url("https://my-app-preview.vercel.app/"), "https://my-app-preview.vercel.app")
        for value in ("http://preview.vercel.app", "https://example.com", "https://user:pass@preview.vercel.app"):
            with self.assertRaises(adapters.AdapterError):
                adapters.validate_preview_url(value)

    def test_vercel_build_and_diagnostics_are_preview_only_and_never_deploy(self):
        (self.root / "vercel.json").write_text('{"version":2}')
        (self.root / ".vercel").mkdir()
        (self.root / ".vercel" / "project.json").write_text('{"projectId":"prj_test","orgId":"team_test"}')
        env = {"VERCEL_TOKEN": "test-token", "VERCEL_PREVIEW_URL": "https://preview-my-app.vercel.app"}
        with patch.dict(os.environ, env, clear=True), patch.object(adapters, "run") as command:
            command.side_effect = ["", "", "Target: Preview", "", "", ""]
            result = adapters.run_vercel(self.root, self.out)
        commands = [call.args[0] for call in command.call_args_list]
        self.assertEqual(result["localBuild"], "passed")
        self.assertEqual(result["preview"], "inspected")
        self.assertIn(["vercel", "pull", "--yes", "--environment=preview"], commands)
        self.assertIn(["vercel", "build"], commands)
        self.assertTrue(all("deploy" not in args and "promote" not in args for args in commands))
        self.assertFalse((self.root / ".vercel" / ".env.preview.local").exists())

    def test_vercel_refuses_production_deployment_target(self):
        (self.root / "vercel.json").write_text('{"version":2}')
        env = {"VERCEL_TOKEN": "test-token", "VERCEL_PREVIEW_URL": "https://preview-my-app.vercel.app"}
        with patch.dict(os.environ, env, clear=True), patch.object(adapters, "run") as command:
            command.side_effect = ["Target: Production"]
            with self.assertRaisesRegex(adapters.AdapterError, "non-preview"):
                adapters.run_vercel(self.root, self.out)

    def test_supabase_commands_are_local_only_and_stop_in_finally(self):
        (self.root / "supabase").mkdir()
        (self.root / "supabase" / "config.toml").write_text('project_id = "test"')
        (self.root / "supabase" / "tests").mkdir()
        (self.root / "supabase" / "tests" / "smoke.sql").write_text("select 1;")
        with patch.dict(os.environ, {"SUPABASE_ACCESS_TOKEN": "must-not-be-forwarded"}), patch.object(adapters.shutil, "which", return_value="/usr/bin/supabase"), patch.object(adapters, "run") as command:
            command.side_effect = ["3.0.0", "", "", "", ""]
            result = adapters.run_supabase(self.root, self.out)
        commands = [call.args[0] for call in command.call_args_list]
        self.assertEqual(result["target"], "local-postgres-only")
        self.assertEqual(commands[0], ["supabase", "--version"])
        self.assertEqual(commands[1][0:2], ["supabase", "start"])
        self.assertIn("edge-runtime", commands[1][3])\n        self.assertIn("analytics", commands[1][3])
        self.assertEqual(commands[2], ["supabase", "db", "reset"])
        self.assertEqual(commands[3], ["supabase", "test", "db"])
        self.assertEqual(commands[4], ["supabase", "stop"])
        self.assertTrue(all("--remote" not in args and "--linked" not in args for args in commands))
        self.assertTrue(all("functions" not in args for args in commands))
        self.assertNotIn("SUPABASE_ACCESS_TOKEN", command.call_args_list[1].args[3])

    def test_supabase_stops_local_stack_after_migration_failure(self):
        (self.root / "supabase").mkdir()
        (self.root / "supabase" / "config.toml").write_text('project_id = "test"')
        with patch.object(adapters.shutil, "which", return_value="/usr/bin/supabase"), patch.object(adapters, "run") as command:
            command.side_effect = ["3.0.0", "", adapters.AdapterError("migration failed"), ""]
            with self.assertRaisesRegex(adapters.AdapterError, "migration failed"):
                adapters.run_supabase(self.root, self.out)
        self.assertEqual(command.call_args_list[-1].args[0], ["supabase", "stop"])

if __name__ == "__main__":
    unittest.main()
