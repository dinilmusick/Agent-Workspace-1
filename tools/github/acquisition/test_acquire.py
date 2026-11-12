import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from acquire import ensure_existing_refs_are_safe


def run_git(repo, *args):
    return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()


class SafeFastForwardResumeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name) / "repo"
        self.repo.mkdir()
        run_git(self.repo, "init", "-b", "main")
        run_git(self.repo, "config", "user.name", "Acquisition Test")
        run_git(self.repo, "config", "user.email", "acquisition-test@example.invalid")
        (self.repo / "file.txt").write_text("first\n")
        run_git(self.repo, "add", "file.txt")
        run_git(self.repo, "commit", "-m", "first")
        self.first = run_git(self.repo, "rev-parse", "HEAD")
        (self.repo / "file.txt").write_text("second\n")
        run_git(self.repo, "commit", "-am", "second")
        self.second = run_git(self.repo, "rev-parse", "HEAD")

    def tearDown(self):
        self.temp.cleanup()

    def test_allows_existing_branch_that_is_behind_by_fast_forward(self):
        ensure_existing_refs_are_safe(
            {"refs/heads/main": self.first},
            {"refs/heads/main": self.second},
            self.repo,
        )

    def test_rejects_divergent_branch_history(self):
        run_git(self.repo, "checkout", "--orphan", "divergent")
        (self.repo / "other.txt").write_text("different history\n")
        run_git(self.repo, "add", "other.txt")
        run_git(self.repo, "commit", "-m", "divergent")
        divergent = run_git(self.repo, "rev-parse", "HEAD")
        with self.assertRaisesRegex(RuntimeError, "not an ancestor"):
            ensure_existing_refs_are_safe(
                {"refs/heads/main": self.second},
                {"refs/heads/main": divergent},
                self.repo,
            )

    def test_rejects_changed_tags(self):
        with self.assertRaisesRegex(RuntimeError, "non-branch ref"):
            ensure_existing_refs_are_safe(
                {"refs/tags/v1": self.first},
                {"refs/tags/v1": self.second},
                self.repo,
            )

    def test_rejects_destination_refs_missing_upstream(self):
        with self.assertRaisesRegex(RuntimeError, "absent upstream"):
            ensure_existing_refs_are_safe(
                {"refs/heads/foreign": self.first},
                {"refs/heads/main": self.second},
                self.repo,
            )


if __name__ == "__main__":
    unittest.main()
