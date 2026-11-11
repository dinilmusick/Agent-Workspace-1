import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("resolve-development-request.py")
SPEC = importlib.util.spec_from_file_location("resolve_development_request", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class DevelopmentRequestTests(unittest.TestCase):
    def issue_event(self, association="COLLABORATOR", body=None):
        return {
            "issue": {
                "title": "[github-dev] verify runner",
                "author_association": association,
                "body": body or (
                    '{"repository":"dinilmusick/Aiko","ref":"main",'
                    '"commands":["node --version","npm test"]}'
                ),
            }
        }

    def test_resolves_authorized_issue_request(self):
        result = MODULE.resolve_request("issues", self.issue_event(), {})
        self.assertEqual(result["repository"], "dinilmusick/Aiko")
        self.assertEqual(result["commands"], "node --version\nnpm test")
        self.assertFalse(result["push"])

    def test_rejects_untrusted_issue_author(self):
        with self.assertRaisesRegex(ValueError, "owner, member, or collaborator"):
            MODULE.resolve_request("issues", self.issue_event("CONTRIBUTOR"), {})

    def test_rejects_wrong_issue_title(self):
        event = self.issue_event()
        event["issue"]["title"] = "ordinary issue"
        with self.assertRaisesRegex(ValueError, "title must start"):
            MODULE.resolve_request("issues", event, {})

    def test_rejects_invalid_repository(self):
        with self.assertRaisesRegex(ValueError, "owner/name"):
            MODULE.validate_request({"repository": "not-a-repository", "commands": "true"})

    def test_requires_branch_when_pushing(self):
        with self.assertRaisesRegex(ValueError, "branch"):
            MODULE.validate_request({
                "repository": "dinilmusick/Aiko",
                "commands": "npm test",
                "push": True,
            })

    def test_pr_requires_push(self):
        with self.assertRaisesRegex(ValueError, "requires push"):
            MODULE.validate_request({
                "repository": "dinilmusick/Aiko",
                "commands": "npm test",
                "create_pr": True,
            })

    def test_rejects_more_than_one_hundred_command_lines(self):
        with self.assertRaisesRegex(ValueError, "100 command lines"):
            MODULE.validate_request({
                "repository": "dinilmusick/Aiko",
                "commands": "\\n".join(["true"] * 101),
            })


if __name__ == "__main__":
    unittest.main()
