import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from acquire import object_set_mismatch, preserve_and_reconcile_existing_refs, safe_provenance_migration, writable_refs


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

    def test_writable_refs_excludes_github_internal_refs(self):
        run_git(self.source, "update-ref", "refs/gh/queue-intermediate-merge-commits/main", self.second)
        run_git(self.source, "update-ref", "refs/pull/1/head", self.second)
        run_git(self.source, "update-ref", "refs/heads/mergify/merge-queue/transient", self.second)
        run_git(self.source, "update-ref", "refs/notes/mergify/mergify/merge-queue/transient", self.second)
        refs = writable_refs(self.source)
        self.assertIn("refs/heads/main", refs)
        self.assertNotIn("refs/gh/queue-intermediate-merge-commits/main", refs)
        self.assertNotIn("refs/pull/1/head", refs)
        self.assertNotIn("refs/heads/mergify/merge-queue/transient", refs)
        self.assertNotIn("refs/notes/mergify/mergify/merge-queue/transient", refs)

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
        run_git(self.source, "tag", "v1", self.second)
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



class ReachableObjectComparisonTests(unittest.TestCase):
    def test_compares_list_inputs_as_sets(self):
        missing, extra = object_set_mismatch(["a", "b", "b"], ["b", "c"])
        self.assertEqual(missing, ["a"])
        self.assertEqual(extra, ["c"])

class ProvenancePinMigrationTests(unittest.TestCase):
    def setUp(self):
        self.old = "a" * 40
        self.new = "b" * 40
        self.source = "spree/spree"
        self.category = "E-commerce + multi-vendor marketplace"
        self.description = f"ULTRST private mirror; upstream={self.source}; commit={self.old}; category={self.category}"
        self.comparison = {"status": "ahead", "ahead_by": 2, "behind_by": 0}

    def migrate(self, **overrides):
        values = {
            "existing_description": self.description,
            "source": self.source,
            "mode": "mirror",
            "category": self.category,
            "old_default_branch": "main",
            "new_default_branch": "main",
            "new_commit": self.new,
            "comparison": self.comparison,
        }
        values.update(overrides)
        return safe_provenance_migration(**values)

    def test_allows_same_source_mode_category_and_verified_fast_forward(self):
        self.assertEqual(self.migrate(), self.old)

    def test_rejects_unrelated_source_or_category(self):
        with self.assertRaisesRegex(RuntimeError, "different source"):
            self.migrate(source="other/project")
        with self.assertRaisesRegex(RuntimeError, "different source"):
            self.migrate(category="Different category")

    def test_rejects_default_branch_rename(self):
        with self.assertRaisesRegex(RuntimeError, "default branch"):
            self.migrate(new_default_branch="trunk")

    def test_rejects_diverged_or_behind_pin(self):
        with self.assertRaisesRegex(RuntimeError, "strict ancestor"):
            self.migrate(comparison={"status": "diverged", "ahead_by": 2, "behind_by": 1})

    def test_rejects_reference_only_or_unchanged_pin_migration(self):
        reference_description = f"ULTRST private reference-only; upstream={self.source}; commit={self.old}; category={self.category}"
        with self.assertRaisesRegex(RuntimeError, "only for private source mirrors"):
            self.migrate(mode="reference-only", existing_description=reference_description)
        with self.assertRaisesRegex(RuntimeError, "unchanged source pin"):
            self.migrate(new_commit=self.old)

    def test_rejects_unrecognized_provenance_marker(self):
        with self.assertRaisesRegex(RuntimeError, "recognized ULTRST"):
            self.migrate(existing_description="unrelated repository description")



if __name__ == "__main__":
    unittest.main()
