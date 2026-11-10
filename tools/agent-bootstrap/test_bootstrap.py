import json, subprocess, sys, tempfile, unittest
from pathlib import Path
SCRIPT = Path(__file__).resolve().parent / "bootstrap.py"

class BootstrapTests(unittest.TestCase):
    def test_plan_reports_build_scripts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / ".git").mkdir()
            (root / "package.json").write_text('{"scripts":{"build":"tsc","test":"node --test"}}')
            result = subprocess.run([sys.executable,str(SCRIPT),"plan","--workspace",str(root/"workspace")],cwd=root,text=True,capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr)
            data=json.loads(result.stdout)
            self.assertEqual(data["build_commands"],[["npm","run","build"],["npm","run","test"]])

    def test_plan_reports_missing_workspace(self):
        with tempfile.TemporaryDirectory() as tmp:
            result=subprocess.run([sys.executable,str(SCRIPT),"plan","--workspace",str(Path(tmp)/"missing")],cwd=tmp,text=True,capture_output=True)
            self.assertEqual(result.returncode,0)
            self.assertIn("Clone Agent-Workspace-1",result.stdout)

if __name__ == "__main__": unittest.main()
