import json
import subprocess
import sys
import tempfile
import unittest
import urllib.request
from pathlib import Path

WORKSPACE = Path(__file__).resolve().parents[1]
RUNNER = Path(__file__).resolve().parent
RUNTIME = RUNNER / "service-runtime.py"
FIXTURE = WORKSPACE / "examples" / "fixture-service.py"

class ServiceRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.state = self.root / "state"
        self.manifest = self.root / "services.json"

    def tearDown(self):
        self.temp.cleanup()

    def write_manifest(self, services):
        self.manifest.write_text(json.dumps({"version": 1, "services": services}), encoding="utf-8")

    def service(self, name, extra=None):
        config = {"id": name, "command": [sys.executable, str(FIXTURE)],
            "env": {"SERVICE_NAME": name}, "port": 0, "port_env": "PORT",
            "healthcheck": {"type": "http", "path": "/health", "interval_seconds": 0.2}}
        if extra:
            config.update(extra)
        return config

    def run_cli(self, action, timeout=8):
        return subprocess.run([sys.executable, str(RUNTIME), action, "--manifest", str(self.manifest),
            "--project-root", str(self.root), "--state-dir", str(self.state),
            "--startup-timeout", str(timeout)], capture_output=True, text=True, timeout=timeout + 5)

    def test_starts_multiple_services_and_stops_them_with_logs_and_ports(self):
        self.write_manifest([self.service("api"), self.service("web")])
        started = self.run_cli("start")
        self.assertEqual(started.returncode, 0, started.stderr)
        state = json.loads((self.state / "state.json").read_text())
        self.assertEqual(state["status"], "ready")
        self.assertNotEqual(state["services"]["api"]["port"], state["services"]["web"]["port"])
        for name, service in state["services"].items():
            with urllib.request.urlopen(f"http://127.0.0.1:{service['port']}/health") as response:
                self.assertEqual(json.loads(response.read())["service"], name)
            self.assertTrue(Path(service["log"]).is_file())
            self.assertIn("fixture service", Path(service["log"]).read_text(encoding="utf-8"))
        stopped = self.run_cli("stop")
        self.assertEqual(stopped.returncode, 0, stopped.stderr)
        self.assertEqual(json.loads((self.state / "state.json").read_text())["status"], "stopped")

    def test_restarts_failed_service_with_bounded_policy(self):
        marker = self.root / "started-once"
        config = self.service("api", {"command": [sys.executable, str(FIXTURE), "--fail-once", str(marker)],
            "restart": {"policy": "on-failure", "max_restarts": 1, "delay_seconds": 0.05}})
        self.write_manifest([config])
        started = self.run_cli("start", timeout=6)
        self.assertEqual(started.returncode, 0, started.stderr)
        state = json.loads((self.state / "state.json").read_text())
        self.assertEqual(state["services"]["api"]["restart_count"], 1)
        self.assertEqual(self.run_cli("stop").returncode, 0)

    def test_startup_exit_and_readiness_timeout_fail_cleanly(self):
        broken = self.service("broken", {"command": [sys.executable, "-c", "raise SystemExit(9)"]})
        self.write_manifest([broken])
        failed = self.run_cli("start", timeout=2)
        self.assertEqual(failed.returncode, 1)
        state = json.loads((self.state / "state.json").read_text())
        self.assertEqual(state["status"], "failed")
        never_ready = self.service("slow", {"healthcheck": {"type": "http", "path": "/never", "interval_seconds": 0.1}})
        self.write_manifest([never_ready])
        timed_out = self.run_cli("start", timeout=1)
        self.assertEqual(timed_out.returncode, 1)
        self.assertEqual(json.loads((self.state / "state.json").read_text())["status"], "failed")

if __name__ == "__main__":
    unittest.main()
