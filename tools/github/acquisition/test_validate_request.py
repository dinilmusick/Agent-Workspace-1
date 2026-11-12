import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_request import APPROVAL_URL, assert_exact_head, catalog_line_authorizes, validate_request_shape, write_outputs

class AcquisitionRequestValidationTests(unittest.TestCase):
    def setUp(self):
        self.request = {"source_repository": "spree/spree", "source_commit": "a" * 40,
            "target_repository": "tpl-commerce-spree", "category": "E-commerce and marketplace",
            "acquisition_mode": "mirror", "approval_record": APPROVAL_URL}

    def test_accepts_complete_valid_request(self):
        self.assertEqual(validate_request_shape(self.request)["target"], "tpl-commerce-spree")

    def test_rejects_missing_and_extra_fields(self):
        with self.assertRaisesRegex(ValueError, "exactly"):
            validate_request_shape({**self.request, "unexpected": "value"})
        incomplete = dict(self.request); del incomplete["source_commit"]
        with self.assertRaisesRegex(ValueError, "exactly"):
            validate_request_shape(incomplete)

    def test_rejects_source_path_injection(self):
        for value in ("../owner/repo", "owner/../repo", "owner/repo\nname", "https://evil.test/x"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_request_shape({**self.request, "source_repository": value})

    def test_rejects_non_tpl_or_malformed_target(self):
        for value in ("other-repo", "tpl-Upper", "tpl-x/../y", "tpl-x\nbad"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_request_shape({**self.request, "target_repository": value})

    def test_requires_full_lowercase_sha(self):
        for value in ("a" * 39, "A" * 40, "g" * 40, "a" * 41):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_request_shape({**self.request, "source_commit": value})

    def test_rejects_unsafe_category(self):
        for value in ("Valid\nINJECT=value", "x; echo bad", "   "):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_request_shape({**self.request, "category": value})

    def test_requires_explicit_recognized_mode(self):
        for value in ("auto", "fork", "mirror\nBAD=1", None):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_request_shape({**self.request, "acquisition_mode": value})

    def test_requires_canonical_authorization_record(self):
        with self.assertRaisesRegex(ValueError, "canonical catalog"):
            validate_request_shape({**self.request, "approval_record": "https://github.com/attacker/repo"})

    def test_rejects_moved_default_branch_head(self):
        with self.assertRaisesRegex(ValueError, "Stale source pin"):
            assert_exact_head("a" * 40, "b" * 40)
        assert_exact_head("a" * 40, "a" * 40)

    def test_catalog_authorization_requires_all_fields_on_same_row(self):
        sha = self.request["source_commit"]
        row = f"| [spree/spree](https://github.com/spree/spree) | tpl-commerce-spree | main | BSD-3-Clause | {sha} |"
        self.assertTrue(catalog_line_authorizes(row, self.request))
        self.assertFalse(catalog_line_authorizes(row.replace("tpl-commerce-spree", "tpl-other"), self.request))
        self.assertFalse(catalog_line_authorizes(row.replace(sha, "b" * 40), self.request))

    def test_workflow_contract_uses_valid_github_expression_delimiters(self):
        workflow_path = Path(__file__).resolve().parents[3] / ".github/workflows/independent-commercial-acquisition.yml"
        workflow = workflow_path.read_text()
        self.assertIn("${{ github.event.issue.number }}", workflow)
        self.assertIn("${{ github.event.repository.default_branch }}", workflow)
        self.assertIn("${{ secrets.CODING_REPO_TOKEN }}", workflow)
        self.assertNotRegex(workflow, r"\$\{ (?:github|secrets|steps|job)\.")
        self.assertIn("actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683", workflow)
        self.assertIn("Independent read-only destination verification", workflow)
        self.assertIn("python3 tools/github/acquisition/verify.py", workflow)
        verifier = Path(__file__).with_name("verify.py").read_text()
        self.assertNotIn('method="POST"', verifier)
        self.assertNotIn('method="PATCH"', verifier)

    def test_github_output_uses_delimited_values(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            write_outputs(str(output), {"SAFE_VALUE": "plain-value", "UNTRUSTED_VALUE": "first-line\nEVIL=1"})
            contents = output.read_text()
            self.assertIn("SAFE_VALUE<<ACQ_", contents)
            self.assertIn("plain-value", contents)
            self.assertIn("UNTRUSTED_VALUE<<ACQ_", contents)
            self.assertIn("first-line\nEVIL=1\n", contents)
            self.assertTrue(contents.endswith("\n"))

if __name__ == "__main__":
    unittest.main()
