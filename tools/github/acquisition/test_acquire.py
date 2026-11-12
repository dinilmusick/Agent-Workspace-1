import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from acquire import preserve_and_reconcile_existing_refs


def run_git(repo, *args, check=True):
    result = subprocess.run(["git", *args], cwd=repo, check=check, capture_output=True, text=True)
    return result.stdout.strip()


def init_repo(path, branch="main", content="first\n"):
    path.mkdir(parents=True, exist_ok=True)
    run_git(path, "init", "-b", branch)
    run_git(path, "config", "user.name", "Acquisition Test")
    run_git(path, "config", "user.email", "acquisition-test@example.invalid")
    (path / "file.txt").write_text(content)
    run_git(path, "add", "file.txt")
    run_git(path, "commit", "-m", "initial")
    return run_git(path, "rev-parse", "HEAD")


class PreserveUpstreamHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.first = init_repo(self.source)
        self.destination = self.root / "destination.git"
        run_git(self.root, "clone", "--bare", str(self.source), str(self.destination))
        (self.source / "file.txt").write_text("second\n")
        run_git(self.source, "commit", "-am", "second")
        self.second = run_git(self.source, "rev-parse", "HEAD")

    def tearDown(self):
        self.temp.cleanup()

    def test_allows_fast_forward_without_creating_archive(self):
        source_refs = {"refs/heads/main": self.second}
        archived = preserve_and_reconcile_existing_refs(
            {"refs/heads/main": self.first}, source_refs, self.source, self.destination
        )
        self.assertEqual(archived, [])
        self.assertEqual(source_refs, {"refs/heads/main": self.second})

    def test_archives_force_pushed_branch_tip_before_replacing(self):
        diverged_destination = self.root / "diverged.git"
        old_sha = init_repo(self.root / "diverged-work", content="old independent branch\n")
        run_git(self.root / "diverged-work", "clone", "--bare", ".", str(diverged_destination))
        source_refs = {"refs/heads/main": self.second}
        archived = preserve_and_reconcile_existing_refs(
            {"refs/heads/main": old_sha}, source_refs, self.source, diverged_destination
        )
        self.assertEqual(len(archived), 1)
        archive_ref = archived[0]["archive_ref"]
        self.assertTrue(archive_ref.startswith("refs/ultrst-archive/"))
        self.assertEqual(source_refs[archive_ref], old_sha)
        self.assertEqual(run_git(self.source, "rev-parse", archive_ref), old_sha)
        self.assertEqual(run_git(self.source, "cat-file", "-t", old_sha), "commit")

    def test_archives_changed_tag_object(self):
        run_git(self.destination, "tag", "v1", self.first)
        source_refs = {"refs/heads/main": self.second, "refs/tags/v1": self.second}
        archived = preserve_and_reconcile_existing_refs(
            {"refs/heads/main": self.first, "refs/tags/v1": self.first},
            source_refs,
            self.source,
            self.destination,
        )
        self.assertEqual(len(archived), 1)
        self.assertEqual(archived[0]["source_ref"], "refs/tags/v1")
        self.assertEqual(run_git(self.source, "rev-parse", archived[0]["archive_ref"]), self.first)

    def test_archives_deleted_upstream_branch_tip(self):
        run_git(self.destination, "branch", "feature", self.first)
        source_refs = {"refs/heads/main": self.second}
        archived = preserve_and_reconcile_existing_refs(
            {"refs/heads/main": self.first, "refs/heads/feature": self.first},
            source_refs,
            self.source,
            self.destination,
        )
        self.assertEqual(len(archived), 1)
        self.assertEqual(archived[0]["source_ref"], "refs/heads/feature")
        self.assertNotIn("refs/heads/feature", source_refs)
        self.assertEqual(run_git(self.source, "rev-parse", archived[0]["archive_ref"]), self.first)


if __name__ == "__main__":
    unittest.main()
