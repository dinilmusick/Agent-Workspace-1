#!/usr/bin/env python3
"""Static contract checks for the GitHub repository helper."""

from pathlib import Path

SOURCE = Path(__file__).with_name("create_repository.py").read_text()


def test_no_hardcoded_token():
    assert "ghp_" not in SOURCE
    assert "github_pat_" not in SOURCE


def test_token_not_cli_argument():
    assert 'add_argument("--token"' not in SOURCE


def test_https_api():
    assert 'https://api.github.com/user/repos' in SOURCE


if __name__ == "__main__":
    test_no_hardcoded_token()
    test_token_not_cli_argument()
    test_https_api()
    print("github repository tool contract checks passed")
