#!/usr/bin/env python3
"""Exercise bootstrap's cache lifecycle without Nix, network, or activation.

Run with: python3 tests/bootstrap.py
"""

import json
from itertools import permutations
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest


REPO = Path(__file__).resolve().parents[1]
APPLIED_CACHE = "http://127.0.0.1:8502"
TEMP_APPLIED_CACHE = "http://127.0.0.1:8503"
APPLIED_KEY = "applied:EpR2bpK4ExMQ38bsZmEMGJKo5qC/xboD/knAQMOMzAY="


def nix_settings(event):
    """Read environment settings followed by command-line overrides."""
    settings = {}
    for line in event["nix_config"].splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            settings[key.strip()] = value.strip()
    args = iter(event["args"])
    for arg in args:
        if arg == "--option":
            key, value = next(args), next(args)
            settings[key] = value
        elif arg in ("--trusted-public-keys", "--extra-trusted-public-keys"):
            settings[arg.removeprefix("--")] = next(args)
    return settings

# Each executable uses the same process double. Markers represent listening ports;
# ncps and SSH are real child processes so ownership and cleanup are tested too.
MOCK_COMMAND = r'''
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

root = Path(os.environ["BOOTSTRAP_TEST_ROOT"])
command = Path(sys.argv[0]).name
args = sys.argv[1:]
ready = root / "cache-ready"
tunnel_ready = root / "tunnel-ready"

def event(name, **values):
    line = json.dumps({"command": name, "args": args,
                       "tunnel_ready": tunnel_ready.exists(),
                       "bootstrap_applied_cache": os.environ.get("DOTFILES_BOOTSTRAP_APPLIED_CACHE"),
                       **values}) + "\n"
    with (root / "events").open("a") as output:
        output.write(line)

event(command, nix_config=os.environ.get("NIX_CONFIG", ""))

if command == "curl":
    url = next(arg for arg in args if arg.startswith("http://"))
    failure = os.environ.get("BOOTSTRAP_TEST_FAIL")
    if url.startswith(("http://127.0.0.1:8502/", "http://127.0.0.1:8503/")):
        if ":8502/" in url and os.environ.get("BOOTSTRAP_TEST_NO_MANAGED_TUNNEL"):
            sys.exit(7)
        if ":8503/" in url and not tunnel_ready.exists():
            sys.exit(7)
        if url.endswith("/nix-cache-info"):
            if failure == "applied-info-unavailable":
                sys.exit(7)
            if failure != "applied-info-empty":
                print("StoreDir: " + ("/wrong/store" if failure == "applied-store-mismatch" else "/nix/store"))
        elif url.endswith("/pubkey"):
            if failure == "applied-key-unavailable":
                sys.exit(22)
            if failure != "applied-key-empty":
                print("wrong:key" if failure == "applied-key-mismatch" else
                      "applied:EpR2bpK4ExMQ38bsZmEMGJKo5qC/xboD/knAQMOMzAY=")
        else:
            sys.exit("unexpected Applied cache endpoint: " + url)
        sys.exit(0)
    if not ready.exists():
        sys.exit(7)
    if url.endswith("/pubkey"):
        print("test-cache:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    sys.exit(0)

if command == "install":
    sys.exit(0)
elif command == "prepare-bootstrap":
    if os.environ.get("BOOTSTRAP_TEST_FAIL") == "prepare":
        sys.exit(29)
    sys.exit(0)
elif command in ("ncps", "ssh"):
    marker = ready if command == "ncps" else tunnel_ready
    def stop(signum, frame):
        marker.unlink(missing_ok=True)
        event(command + "-stopped")
        sys.exit(0)
    signal.signal(signal.SIGTERM, stop)
    (root / (command + "-pid")).write_text(str(os.getpid()))
    if os.environ.get("BOOTSTRAP_TEST_FAIL") == command + "-exit":
        sys.exit("mock " + command + " startup failure")
    if os.environ.get("BOOTSTRAP_TEST_FAIL") != command + "-hang":
        marker.touch()
    while True:
        signal.pause()
elif command == "nix":
    if "build" in args:
        configuration = " ".join(args) + " " + os.environ.get("NIX_CONFIG", "")
        using_applied = any("http://127.0.0.1:" + port in configuration for port in ("8502", "8503"))
        if "http://127.0.0.1:8503" in configuration and not tunnel_ready.exists():
            sys.exit("temporary Applied tunnel stopped before build")
        if not using_applied and (root / "home/code/.nix-cache/ncps").exists() and not ready.exists():
            sys.exit("build cannot connect to port 8501")
        if os.environ.get("BOOTSTRAP_TEST_FAIL") == "build":
            sys.exit(19)
        result = Path(args[args.index("--out-link") + 1])
        result.symlink_to(root / "activation", target_is_directory=True)
    elif "copy" not in args:
        sys.exit("unexpected nix invocation: " + repr(args))
elif command == "activate":
    # Home Manager installs the profile before starting the managed cache. A
    # previously saved nix.conf still points at the service that is currently down.
    subprocess.run([str(root / "bin/nix-env"), "--set", "restored-profile"], check=True)
    if os.environ.get("BOOTSTRAP_TEST_FAIL") == "activate":
        sys.exit(23)
    event("activation-complete")
elif command == "nix-env":
    settings = {
        "substituters": "http://127.0.0.1:8501",
        "extra-substituters": "http://127.0.0.1:8501",
        "post-build-hook": "/old-profile/bin/upload-to-ncps",
    }
    for line in os.environ.get("NIX_CONFIG", "").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            settings[key.strip()] = value.strip()
    if "http://127.0.0.1:8501" in (settings["substituters"] + " " + settings["extra-substituters"]) and not ready.exists():
        sys.exit("activation cannot connect to port 8501")
    if "http://127.0.0.1:8503" in settings["substituters"] and not tunnel_ready.exists():
        sys.exit("temporary Applied tunnel stopped before activation")
    if settings["post-build-hook"]:
        sys.exit("activation attempted to run stale post-build-hook")
else:
    sys.exit("unexpected command: " + command)
'''


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-bootstrap-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.tmp = self.root / "tmp"
        self.cache = self.home / "code/.nix-cache/ncps"
        for directory in (self.repo / "nix", self.home, self.bin, self.tmp,
                          self.root / "activation", self.root / "ncps/bin"):
            directory.mkdir(parents=True)
        shutil.copy2(REPO / "bootstrap", self.repo / "bootstrap")
        shutil.copy2(REPO / "nix/applied-cache-tunnel", self.repo / "nix/applied-cache-tunnel")
        for path in (self.repo / "nix/install", self.repo / "nix/prepare-bootstrap",
                     self.bin / "nix", self.bin / "curl", self.bin / "nix-env", self.bin / "ssh",
                     self.root / "activation/activate", self.root / "ncps/bin/ncps"):
            path.write_text(f"#!{sys.executable}\n" + MOCK_COMMAND)
            path.chmod(0o755)

        # Shell functions outrank even bootstrap's hard-coded /nix PATH entry.
        # No edits to the production script or installed Nix are needed.
        shell_env = self.root / "bash-env"
        shell_env.write_text('''\
nix() { "$BOOTSTRAP_TEST_ROOT/bin/nix" "$@"; }
curl() { "$BOOTSTRAP_TEST_ROOT/bin/curl" "$@"; }
sleep() {
  case "${BOOTSTRAP_TEST_FAIL:-}" in
    ncps-hang|ssh-hang|applied-info-unavailable) SECONDS=$((SECONDS + 10)) ;;
    *) command sleep "$@" ;;
  esac
}
''')
        self.env = dict(os.environ, HOME=str(self.home), TMPDIR=str(self.tmp),
                        PATH=f"{self.bin}:{os.environ['PATH']}", BASH_ENV=str(shell_env),
                        SSH_BIN=str(self.bin / "ssh"),
                        BOOTSTRAP_TEST_ROOT=str(self.root),
                        DOTFILES_BOOTSTRAP_APPLIED_CACHE=APPLIED_CACHE,
                        NIX_CONFIG="""\
substituters = http://127.0.0.1:8501
extra-substituters = http://127.0.0.1:8501
post-build-hook = /old-profile/bin/upload-to-ncps
experimental-features = nix-command flakes
""")
        self.env.pop("BOOTSTRAP_TEST_FAIL", None)
        self.env.pop("BOOTSTRAP_TEST_NO_MANAGED_TUNNEL", None)
        self.env.pop("HOME_MANAGER_BACKUP_EXT", None)
        self.addCleanup(self.stop_leaked_cache)

    def seed_cache(self):
        (self.cache / "bootstrap").mkdir(parents=True)
        (self.cache / "bootstrap/ncps-path").write_text(str(self.root / "ncps") + "\n")

    def events(self):
        path = self.root / "events"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def stop_leaked_cache(self):
        for command in ("ncps", "ssh"):
            pid_path = self.root / (command + "-pid")
            if pid_path.exists():
                try:
                    os.kill(int(pid_path.read_text()), signal.SIGTERM)
                except ProcessLookupError:
                    pass

    def run_bootstrap(self, *args, failure=None):
        env = self.env.copy()
        if failure:
            env["BOOTSTRAP_TEST_FAIL"] = failure
        result = subprocess.run(["bash", str(self.repo / "bootstrap"), *args],
                                env=env, capture_output=True, text=True, timeout=15)
        self.assertEqual(list(self.tmp.iterdir()), [], "bootstrap left temporary files behind")
        return result

    def assert_success(self, result, profile="brix-root", applied=False):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        events = self.events()
        commands = [event["command"] for event in events]
        self.assertIn("activation-complete", commands)
        prepared = [event for event in events if event["command"] == "prepare-bootstrap"]
        self.assertEqual([event["args"] for event in prepared], [[profile]])
        self.assertEqual(prepared[0]["nix_config"], self.env["NIX_CONFIG"])
        self.assertLess(commands.index("activation-complete"), commands.index("prepare-bootstrap"))
        activation = next(event for event in events if event["command"] == "activate")
        self.assertIn("experimental-features = nix-command flakes", activation["nix_config"])
        if not applied:
            self.assertEqual(activation["bootstrap_applied_cache"], "")
            self.assertFalse(any(any(url in " ".join(event["args"])
                                     for url in (APPLIED_CACHE, TEMP_APPLIED_CACHE))
                                 for event in events if event["command"] == "curl"))
            self.assertNotIn("ssh", commands)

    def assert_applied_success(self, result, profile="brix-root", temporary=False):
        self.assert_success(result, profile=profile, applied=True)
        events = self.events()
        self.assertNotIn("ncps", [event["command"] for event in events])
        self.assertFalse(any(event["command"] == "nix" and "copy" in event["args"]
                             for event in events))
        probes = [event for event in events if event["command"] == "curl"]
        urls = [arg for probe in probes for arg in probe["args"] if arg.startswith("http://")]
        applied_cache = TEMP_APPLIED_CACHE if temporary else APPLIED_CACHE
        activation = next(event for event in events if event["command"] == "activate")
        self.assertEqual(activation["bootstrap_applied_cache"], applied_cache)
        if temporary:
            self.assertIn(APPLIED_CACHE + "/nix-cache-info", urls)
            self.assertIn(applied_cache + "/nix-cache-info", urls)
            self.assertIn(applied_cache + "/pubkey", urls)
            self.assertEqual(set(urls), {APPLIED_CACHE + "/nix-cache-info",
                                         applied_cache + "/nix-cache-info", applied_cache + "/pubkey"})
            self.assert_owned_tunnel_stopped_after("prepare-bootstrap")
            for event in events:
                if event["command"] in ("activate", "prepare-bootstrap"):
                    self.assertTrue(event["tunnel_ready"], "temporary tunnel stopped before " + event["command"])
            ssh = next(event for event in events if event["command"] == "ssh")
            self.assert_tunnel_arguments(ssh["args"], port="8503")
        else:
            self.assertCountEqual(urls, [applied_cache + "/nix-cache-info", applied_cache + "/pubkey"])
            self.assertNotIn("ssh", [event["command"] for event in events])
        install_index = next(i for i, event in enumerate(events) if event["command"] == "install")
        for probe in probes:
            self.assertLess(events.index(probe), install_index)
            args = probe["args"]
            timeout_flag = "--max-time" if "--max-time" in args else "-m"
            self.assertIn(timeout_flag, args, "cache preflight must have a time limit")
            self.assertGreater(float(args[args.index(timeout_flag) + 1]), 0)
            self.assertLessEqual(float(args[args.index(timeout_flag) + 1]), 30)
        for event in events:
            if event["command"] == "activate" or (event["command"] == "nix" and "build" in event["args"]):
                settings = nix_settings(event)
                self.assertEqual(settings.get("substituters"), applied_cache)
                self.assertEqual(settings.get("extra-substituters"), "")
                self.assertEqual(settings.get("post-build-hook"), "")
                self.assertEqual(settings.get("builders"), "")
                self.assertEqual(settings.get("max-jobs"), "1")
                keys = settings.get("trusted-public-keys", "") + " " + settings.get("extra-trusted-public-keys", "")
                self.assertIn(APPLIED_KEY, keys.split())

    def assert_tunnel_arguments(self, args, port):
        self.assertIn("isaact@127.0.0.1", args)
        self.assertIn("-p", args)
        self.assertEqual(args[args.index("-p") + 1], "2222")
        self.assertIn("-L", args)
        forward = args[args.index("-L") + 1].split(":")
        self.assertEqual(forward[:2], ["127.0.0.1", port])
        self.assertIn(forward[2], ("localhost", "127.0.0.1"))
        self.assertEqual(forward[3], "8501")
        self.assertIn(str(self.home / ".ssh/id_rsa"), args)
        self.assertIn("BatchMode=yes", args)
        self.assertIn("ExitOnForwardFailure=yes", args)
        self.assertIn("ControlMaster=no", args)
        self.assertIn("ForkAfterAuthentication=no", args)

    def assert_owned_tunnel_stopped_after(self, command):
        commands = [event["command"] for event in self.events()]
        self.assertEqual(commands.count("ssh"), 1)
        self.assertEqual(commands.count("ssh-stopped"), 1)
        self.assertLess(commands.index("ssh"), commands.index("ssh-stopped"))
        self.assertLess(commands.index(command), commands.index("ssh-stopped"))
        self.assertFalse((self.root / "tunnel-ready").exists())

    def test_restored_cache_is_running_for_build_and_stopped_before_activation(self):
        self.seed_cache()
        result = self.run_bootstrap("--yes", "custom-profile")
        self.assert_success(result, profile="custom-profile")
        commands = [event["command"] for event in self.events()]
        self.assertLess(commands.index("ncps"), commands.index("ncps-stopped"))
        self.assertLess(commands.index("ncps-stopped"), commands.index("activate"))
        self.assertFalse((self.root / "cache-ready").exists())
        installed = next(event for event in self.events() if event["command"] == "install")
        self.assertEqual(installed["args"], ["--yes"])

    def test_first_bootstrap_also_isolates_activation_from_stale_config(self):
        result = self.run_bootstrap()
        self.assert_success(result)
        self.assertNotIn("ncps", [event["command"] for event in self.events()])

    def test_existing_cache_service_is_not_stopped(self):
        self.seed_cache()
        service = subprocess.Popen([str(self.root / "ncps/bin/ncps"), "serve"], env=self.env)
        self.addCleanup(service.wait, 5)
        self.addCleanup(service.terminate)
        deadline = time.monotonic() + 5
        while not (self.root / "cache-ready").exists():
            self.assertIsNone(service.poll(), "mock service failed to start")
            self.assertLess(time.monotonic(), deadline, "mock service startup timed out")
            time.sleep(0.01)
        result = self.run_bootstrap()
        self.assert_success(result)
        self.assertIsNone(service.poll())
        self.assertTrue((self.root / "cache-ready").exists())
        self.assertNotIn("ncps-stopped", [event["command"] for event in self.events()])
        self.assertEqual(sum(event["command"] == "ncps" for event in self.events()), 1)

    def test_build_failure_cleans_up_without_activating_or_preparing(self):
        self.seed_cache()
        result = self.run_bootstrap(failure="build")
        self.assertNotEqual(result.returncode, 0)
        commands = [event["command"] for event in self.events()]
        self.assertIn("ncps-stopped", commands)
        self.assertNotIn("activate", commands)
        self.assertNotIn("prepare-bootstrap", commands)
        self.assertFalse((self.root / "cache-ready").exists())

    def test_activation_failure_does_not_refresh_bootstrap_cache(self):
        self.seed_cache()
        result = self.run_bootstrap(failure="activate")
        self.assertNotEqual(result.returncode, 0)
        commands = [event["command"] for event in self.events()]
        self.assertIn("activate", commands)
        self.assertNotIn("activation-complete", commands)
        self.assertNotIn("prepare-bootstrap", commands)
        self.assertFalse((self.root / "cache-ready").exists())

    def test_missing_starter_metadata_reports_how_to_repair_it(self):
        self.cache.mkdir(parents=True)
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ncps-path", result.stderr)
        self.assertIn("prepare-bootstrap", result.stderr)
        self.assertNotIn("activate", [event["command"] for event in self.events()])

    def test_proxy_startup_failure_prints_its_log(self):
        self.seed_cache()
        result = self.run_bootstrap(failure="ncps-exit")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("mock ncps startup failure", result.stderr)
        self.assertNotIn("activate", [event["command"] for event in self.events()])

    def test_proxy_startup_has_a_deadline_and_cleans_up(self):
        self.seed_cache()
        result = self.run_bootstrap(failure="ncps-hang")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Timed out", result.stderr)
        commands = [event["command"] for event in self.events()]
        self.assertIn("ncps-stopped", commands)
        self.assertNotIn("activate", commands)

    def test_applied_mode_bootstraps_without_local_cache(self):
        result = self.run_bootstrap("--use-applied-cache")
        self.assert_applied_success(result)

    def test_applied_mode_bootstraps_with_missing_local_manifest(self):
        self.cache.mkdir(parents=True)
        result = self.run_bootstrap("--use-applied-cache")
        self.assert_applied_success(result)

    def test_applied_mode_bypasses_available_local_starter_cache(self):
        self.seed_cache()
        result = self.run_bootstrap("--use-applied-cache")
        self.assert_applied_success(result)

    def test_applied_mode_rejects_bad_preflight_before_install(self):
        for failure in ("applied-info-unavailable", "applied-info-empty",
                        "applied-store-mismatch", "applied-key-unavailable",
                        "applied-key-empty", "applied-key-mismatch"):
            with self.subTest(failure=failure):
                (self.root / "events").write_text("")
                result = self.run_bootstrap("--use-applied-cache", failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr.strip(), "preflight failure needs a diagnostic")
                commands = [event["command"] for event in self.events()]
                self.assertIn("curl", commands)
                self.assertNotIn("install", commands)
                self.assertNotIn("nix", commands)
                self.assertNotIn("activate", commands)
                self.assertNotIn("prepare-bootstrap", commands)
                if failure != "applied-info-unavailable":
                    self.assertNotIn("ssh", commands, "reachable cache with invalid identity must not trigger fallback")

    def test_applied_options_and_profile_accept_any_order(self):
        for args in permutations(("--yes", "--use-applied-cache", "custom-profile")):
            with self.subTest(args=args):
                (self.root / "events").write_text("")
                result = self.run_bootstrap(*args)
                self.assert_applied_success(result, profile="custom-profile")
                installed = next(event for event in self.events() if event["command"] == "install")
                self.assertEqual(installed["args"], ["--yes"])
                build = next(event for event in self.events() if event["command"] == "nix" and "build" in event["args"])
                self.assertTrue(any(arg.endswith("#homeConfigurations.custom-profile.activationPackage")
                                    for arg in build["args"]))

    def test_default_mode_accepts_yes_after_profile(self):
        result = self.run_bootstrap("custom-profile", "--yes")
        self.assert_success(result, profile="custom-profile")
        installed = next(event for event in self.events() if event["command"] == "install")
        self.assertEqual(installed["args"], ["--yes"])

    def test_unknown_options_and_multiple_profiles_are_rejected(self):
        for args in (("--unknown",), ("first", "second"),
                     ("--use-applied-cache", "--unknown"),
                     ("first", "--use-applied-cache", "second")):
            with self.subTest(args=args):
                (self.root / "events").write_text("")
                result = self.run_bootstrap(*args)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertTrue(result.stderr.strip())
                self.assertEqual(self.events(), [], "invalid arguments must be rejected before any work")

    def test_applied_mode_build_and_activation_failures_cleanup(self):
        for failure in ("build", "activate"):
            with self.subTest(failure=failure):
                (self.root / "events").write_text("")
                result = self.run_bootstrap("--use-applied-cache", failure=failure)
                self.assertNotEqual(result.returncode, 0)
                commands = [event["command"] for event in self.events()]
                self.assertNotIn("ncps", commands)
                self.assertNotIn("prepare-bootstrap", commands)
                self.assertNotIn("activation-complete", commands)
                self.assertEqual("activate" in commands, failure == "activate")

    def test_applied_mode_starts_tunnel_through_activation_and_preparation(self):
        self.env["BOOTSTRAP_TEST_NO_MANAGED_TUNNEL"] = "1"
        self.cache.mkdir(parents=True)  # Recovery must not need a local manifest.
        result = self.run_bootstrap("--use-applied-cache")
        self.assert_applied_success(result, temporary=True)

    def test_temporary_tunnel_cleanup_after_build_activation_or_preparation_failure(self):
        self.env["BOOTSTRAP_TEST_NO_MANAGED_TUNNEL"] = "1"
        for failure in ("build", "activate", "prepare"):
            with self.subTest(failure=failure):
                (self.root / "events").write_text("")
                result = self.run_bootstrap("--use-applied-cache", failure=failure)
                self.assertNotEqual(result.returncode, 0)
                failed_command = "nix" if failure == "build" else "prepare-bootstrap" if failure == "prepare" else "activate"
                self.assert_owned_tunnel_stopped_after(failed_command)
                attempted = next(event for event in self.events() if event["command"] == failed_command)
                self.assertTrue(attempted["tunnel_ready"])

    def test_temporary_tunnel_invalid_cache_identity_is_rejected_and_cleaned_up(self):
        self.env["BOOTSTRAP_TEST_NO_MANAGED_TUNNEL"] = "1"
        for failure in ("applied-info-empty", "applied-store-mismatch",
                        "applied-key-unavailable", "applied-key-empty", "applied-key-mismatch"):
            with self.subTest(failure=failure):
                (self.root / "events").write_text("")
                result = self.run_bootstrap("--use-applied-cache", failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr.strip())
                self.assert_owned_tunnel_stopped_after("curl")
                self.assertNotIn("install", [event["command"] for event in self.events()])

    def test_tunnel_startup_failure_prints_ssh_log_and_does_not_install(self):
        self.env["BOOTSTRAP_TEST_NO_MANAGED_TUNNEL"] = "1"
        result = self.run_bootstrap("--use-applied-cache", failure="ssh-exit")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("mock ssh startup failure", result.stderr)
        self.assertNotIn("install", [event["command"] for event in self.events()])
        self.assertFalse((self.root / "tunnel-ready").exists())

    def test_tunnel_startup_has_a_deadline_and_cleans_up(self):
        self.env["BOOTSTRAP_TEST_NO_MANAGED_TUNNEL"] = "1"
        result = self.run_bootstrap("--use-applied-cache", failure="ssh-hang")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Timed out", result.stderr)
        self.assert_owned_tunnel_stopped_after("curl")
        self.assertNotIn("install", [event["command"] for event in self.events()])

    def test_occupied_temporary_port_does_not_mask_ssh_failure(self):
        self.env["BOOTSTRAP_TEST_NO_MANAGED_TUNNEL"] = "1"
        (self.root / "tunnel-ready").touch()  # An unrelated process owns 8503.
        result = self.run_bootstrap("--use-applied-cache", failure="ssh-exit")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("mock ssh startup failure", result.stderr)
        self.assertNotIn("install", [event["command"] for event in self.events()])
        self.assertTrue((self.root / "tunnel-ready").exists(), "must not stop an unrelated listener")

    def test_shared_tunnel_helper_defaults_to_managed_port(self):
        service = subprocess.Popen(["bash", str(self.repo / "nix/applied-cache-tunnel")], env=self.env)
        self.addCleanup(service.wait, 5)
        self.addCleanup(service.terminate)
        deadline = time.monotonic() + 5
        while not (self.root / "tunnel-ready").exists():
            self.assertIsNone(service.poll(), "tunnel helper failed to start")
            self.assertLess(time.monotonic(), deadline, "tunnel helper startup timed out")
            time.sleep(0.01)
        ssh = next(event for event in self.events() if event["command"] == "ssh")
        self.assert_tunnel_arguments(ssh["args"], port="8502")


if __name__ == "__main__":
    unittest.main()
