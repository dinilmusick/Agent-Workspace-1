import re
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_request import APPROVAL_URL, assert_exact_head, catalog_authorization, catalog_line_authorizes, validate_catalog_authorization, validate_request_shape, write_outputs

class AcquisitionRequestValidationTests(unittest.TestCase):
    def setUp(self):
        self.request = {"source_repository": "spree/spree", "source_commit": "a" * 40,
            "target_repository": "tpl-commerce-spree", "category": "E-commerce + multi-vendor marketplace",
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
        catalog = f"""## 2. Additional full-source private research mirrors
| Product category | Upstream source | Destination repository | Branch | GitHub SPDX | Pinned source commit | Why |
| E-commerce + multi-vendor marketplace | [spree/spree](https://github.com/spree/spree) | `tpl-commerce-spree` | main | BSD-3-Clause | `{sha}` | test |
## 3. Additional reference-only candidates
| Product category | Upstream source | Destination repository | Branch | Pinned source commit | Why |
| AI workflow builder | [langgenius/dify](https://github.com/langgenius/dify) | `tpl-ai-dify` | main | `{sha}` | test |
"""
        authorization = catalog_authorization(catalog, self.request)
        self.assertEqual(authorization, {"branch": "main", "mode": "mirror", "category": self.request["category"], "license": "BSD-3-Clause"})
        self.assertTrue(catalog_line_authorizes(catalog, self.request))
        self.assertFalse(catalog_line_authorizes(catalog.replace("tpl-commerce-spree", "tpl-other"), self.request))
        self.assertFalse(catalog_line_authorizes(catalog.replace(sha, "b" * 40, 1), self.request))
        self.assertEqual(validate_catalog_authorization(catalog, self.request, "main", "BSD-3-Clause")["mode"], "mirror")
        with self.assertRaisesRegex(ValueError, "default branch mismatch"):
            validate_catalog_authorization(catalog, self.request, "master", "BSD-3-Clause")
        with self.assertRaisesRegex(ValueError, "Acquisition mode mismatch"):
            validate_catalog_authorization(catalog, {**self.request, "acquisition_mode": "reference-only"}, "main", "BSD-3-Clause")
        with self.assertRaisesRegex(ValueError, "category"):
            validate_catalog_authorization(catalog, {**self.request, "category": "Wrong category"}, "main", "BSD-3-Clause")
        with self.assertRaisesRegex(ValueError, "SPDX metadata"):
            validate_catalog_authorization(catalog, self.request, "main", "MIT")

    def test_reference_only_catalog_row_requires_reference_only_mode(self):
        sha = self.request["source_commit"]
        catalog = f"""## 3. Additional reference-only candidates
| Product category | Upstream source | Destination repository | Branch | Pinned source commit | Why |
| AI workflow builder | [langgenius/dify](https://github.com/langgenius/dify) | `tpl-ai-dify` | main | `{sha}` | test |
"""
        request = {**self.request, "source_repository": "langgenius/dify", "target_repository": "tpl-ai-dify",
                   "category": "AI workflow builder", "acquisition_mode": "reference-only"}
        self.assertEqual(validate_catalog_authorization(catalog, request, "main", "NOASSERTION")["mode"], "reference-only")

    def test_canonical_catalog_authorizes_all_35_candidates(self):
        catalog_path = Path(__file__).resolve().parents[3] / "docs/template-portfolio-catalog.md"
        catalog = catalog_path.read_text()
        mode = None
        counts = {"mirror": 0, "reference-only": 0}
        for line in catalog.splitlines():
            heading = line.strip().lower()
            if heading.startswith("## "):
                if "additional full-source private research mirrors" in heading:
                    mode = "mirror"
                elif "additional reference-only candidates" in heading:
                    mode = "reference-only"
                else:
                    mode = None
            if mode is None or not line.lstrip().startswith("|"):
                continue
            cells = [cell.strip() for cell in line.split("|")]
            if len(cells) < 6:
                continue
            source_match = re.search(r"https://github\\.com/([^/]+)/([^/)\\s]+)", cells[2], re.IGNORECASE)
            if not source_match:
                continue
            commit_cell = cells[6] if mode == "mirror" else cells[5]
            commit_match = re.search(r"[0-9a-f]{40}", commit_cell)
            if not commit_match:
                continue
            source = f"{source_match.group(1)}/{source_match.group(2)}"
            target = cells[3].strip().strip("`")
            branch = cells[4].strip().strip("`")
            category = cells[1].strip().strip("`")
            license_id = cells[5].strip().strip("`") if mode == "mirror" else "NOASSERTION"
            request = {"source_repository": source, "target_repository": target,
                       "source_commit": commit_match.group(0), "category": category,
                       "acquisition_mode": mode}
            authorization = validate_catalog_authorization(catalog, request, branch, license_id)
            self.assertEqual(authorization["branch"], branch)
            self.assertEqual(authorization["mode"], mode)
            counts[mode] += 1
        self.assertEqual(counts, {"mirror": 29, "reference-only": 6})

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
        self.assertIn("python3 -m unittest discover -s tools/github/acquisition", workflow)
        verifier = Path(__file__).with_name("verify.py").read_text()
        self.assertNotIn('method="POST"', verifier)
        self.assertNotIn('method="PATCH"', verifier)
        self.assertIn("live_license", verifier)
        self.assertIn('rev-list","--count"', verifier)
        self.assertIn("refs/ultrst-archive/", verifier)
        acquisition = Path(__file__).with_name("acquire.py").read_text()
        self.assertIn("preserve_and_reconcile_existing_refs", acquisition)

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
