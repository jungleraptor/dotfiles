#!/usr/bin/env python3
"""Test the managed bk wrapper offline using private, fake credentials only.

Run with: python3 tests/buildkite.py /path/to/wrapped/bin/bk
"""

import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


BK_BINARY = None
ORG = "openai-mono"
ACCESS_TOKEN = "fake-access"
REFRESH_TOKEN = "fake-refresh"
ACCESS_SERVICE = "buildkite-cli"
REFRESH_SERVICE = "buildkite-cli-refresh"


class BuildkiteCredentialTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-buildkite-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.store_dir = self.root / "persistent-credentials"
        self.store_dir.mkdir(mode=0o700)
        self.store = self.store_dir / "credentials.json"
        self.store.write_text(json.dumps({
            "services": {
                ACCESS_SERVICE: {ORG: ACCESS_TOKEN},
                REFRESH_SERVICE: {ORG: REFRESH_TOKEN},
            },
            "preferred_stores": {
                ACCESS_SERVICE: {ORG: "shm"},
                REFRESH_SERVICE: {ORG: "shm"},
            },
        }))
        self.store.chmod(0o600)
        self.home = self.new_home("first-home")

    def new_home(self, name):
        home = self.root / name
        home.mkdir(mode=0o700)
        (home / ".config").mkdir(mode=0o700)
        return home

    def run_bk(self, *args, home=None):
        home = home or self.home
        # Do not inherit API tokens, CLI configuration, proxies, shell hooks,
        # or any credential-store settings from the developer's environment.
        # Both commands below are local store operations, with no API requests.
        env = {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "BUILDKITE_CREDENTIAL_STORE_PATH": str(self.store),
            "PATH": os.defpath,
            "NO_COLOR": "1",
            "TERM": "dumb",
        }
        return subprocess.run(
            [str(BK_BINARY), "--no-input", *args],
            cwd=self.root,
            env=env,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def assert_fake_token(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), ACCESS_TOKEN)

    def assert_no_credentials(self):
        data = json.loads(self.store.read_text()) if self.store.exists() else {}
        for service in (ACCESS_SERVICE, REFRESH_SERVICE):
            self.assertNotIn(ORG, data.get("services", {}).get(service, {}))

    def test_fresh_home_uses_default_org_without_bk_configuration(self):
        self.assertEqual(list(self.home.rglob("bk.yaml")), [])
        self.assert_fake_token(self.run_bk("auth", "token"))
        self.assertEqual(list(self.home.rglob("bk.yaml")), [])
        self.assertEqual(stat.S_IMODE(self.store_dir.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(self.store.stat().st_mode), 0o600)

    def test_second_fresh_home_reuses_persistent_store(self):
        self.assert_fake_token(self.run_bk("auth", "token"))
        second_home = self.new_home("replacement-home")
        self.assert_fake_token(self.run_bk("auth", "token", home=second_home))
        self.assertEqual(list(second_home.rglob("bk.yaml")), [])

    def test_logout_removes_access_and_refresh_without_recreating_them(self):
        self.assert_fake_token(self.run_bk("auth", "token"))
        result = self.run_bk("auth", "logout")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_no_credentials()

        result = self.run_bk("auth", "token")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assert_no_credentials()

    def test_existing_world_readable_directory_is_rejected(self):
        self.store_dir.chmod(0o755)
        result = self.run_bk("auth", "token")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(stat.S_IMODE(self.store_dir.stat().st_mode), 0o755)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__.strip())
    BK_BINARY = Path(sys.argv[1]).resolve(strict=True)
    unittest.main(argv=[sys.argv[0], *sys.argv[2:]])
