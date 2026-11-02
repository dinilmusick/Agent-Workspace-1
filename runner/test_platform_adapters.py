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
        (self.root / "vitest.config.ts").write_text("export default {};")
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
            command.side_effect = ["Target: Preview", "", "", ""]
            result = adapters.run_vercel(self.root, self.out)
        commands = [call.args[0] for call in command.call_args_list]
        self.assertEqual(result["localBuild"], "passed")
        self.assertEqual(result["preview"], "inspected")
        self.assertIn(["vercel", "pull", "--yes", "--environment=preview"], commands)
        self.assertIn(["vercel", "build"], commands)
        self.assertTrue(all("deploy" not in args and "promote" not in args for args in commands))

    def test_supabase_commands_are_local_only_and_stop_in_finally(self):
        (self.root / "supabase").mkdir()
        (self.root / "supabase" / "config.toml").write_text("project_id = \"test\"")
        (self.root / "supabase" / "tests").mkdir()
        (self.root / "supabase" / "tests" / "smoke.sql").write_text("select 1;")
        with patch.object(adapters.shutil, "which", return_value="/usr/bin/supabase"), patch.object(adapters, "run") as command:
            result = adapters.run_supabase(self.root, self.out)
        commands = [call.args[0] for call in command.call_args_list]
        self.assertEqual(result["target"], "local-postgres-only")
        self.assertEqual(commands[0][0:2], ["supabase", "start"])
        self.assertIn("edge-runtime", commands[0][3])
        self.assertEqual(commands[1], ["supabase", "db", "reset"])
        self.assertEqual(commands[2], ["supabase", "test", "db"])
        self.assertEqual(commands[3], ["supabase", "stop"])
        self.assertTrue(all("--remote" not in args and "--linked" not in args for args in commands))
        self.assertTrue(all("functions" not in args for args in commands))

if __name__ == "__main__":
    unittest.main()
