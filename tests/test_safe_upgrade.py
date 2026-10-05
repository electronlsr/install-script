import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import tarfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("upgrade", ROOT / "scripts/safe_upgrade.py")
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)


def fixture(name="trojan-panel", root="/tpdata"):
    return {"Id": "old-" + name, "Name": "/" + name, "Image": "sha256:old-" + name,
            "Config": {"Image": "jonssonyan/" + name, "Env": ["mariadb_pas=secret with = signs", "account_table=custom_accounts"],
                       "Entrypoint": ["/bin/sh", "-c", "old startup"], "Cmd": None, "WorkingDir": "/tpdata/" + name,
                       "User": "", "Labels": {"custom": "keep"}},
            "HostConfig": {"RestartPolicy": {"Name": "always", "MaximumRetryCount": 0}, "NetworkMode": "host",
                           "Binds": [root + "/" + name + "/config:/tpdata/" + name + "/config:rw"], "AutoRemove": False},
            "State": {"Running": True}, "Mounts": [{"Type": "bind", "Source": root + "/" + name + "/config",
                                                     "Destination": "/tpdata/" + name + "/config", "RW": True}]}


class FakeDocker:
    def __init__(self, names, root):
        self.containers = {name: fixture(name, root) for name in names}
        self.images = {}
        self.events = []
        self.fail_pull = None
        self.fail_create = None
        self.fail_start = None
        for name, container in self.containers.items():
            self.images[container["Image"]] = {"Id": container["Image"], "Config": copy.deepcopy(container["Config"])}
            self.images["ghcr.io/electronlsr/" + name + ":2026.10.05-r1"] = {"Id": "sha256:new-" + name, "Config": {}}

    def lookup(self, ref):
        if ref in self.containers:
            return self.containers[ref]
        for container in self.containers.values():
            if container["Id"] == ref:
                return container
        raise u.UpgradeError("not found " + ref)

    def inspect(self, ref, kind="container"):
        return copy.deepcopy(self.images[ref] if kind == "image" else self.lookup(ref))

    def inspect_optional(self, ref):
        try:
            return self.inspect(ref)
        except u.UpgradeError:
            return None

    def docker(self, *args):
        self.events.append(args)
        if args[0] == "pull":
            if args[1] == self.fail_pull:
                raise u.UpgradeError("pull failed")
        elif args[0] == "exec":
            return "v2.3.0" if args[1] == "trojan-panel-ui" else "v2.3.1"
        elif args[0] == "update":
            self.lookup(args[2])["HostConfig"]["RestartPolicy"]["Name"] = args[1].split("=", 1)[1]
        elif args[0] == "stop":
            self.lookup(args[-1])["State"]["Running"] = False
        elif args[0] == "rename":
            if args[2] in self.containers:
                raise u.UpgradeError("name exists")
            container = self.containers.pop(args[1])
            container["Name"] = "/" + args[2]
            self.containers[args[2]] = container
        elif args[0] == "start":
            if args[1] == self.fail_start:
                raise u.UpgradeError("start failed")
            self.lookup(args[1])["State"]["Running"] = True
        elif args[0] == "rm":
            container = self.lookup(args[-1])
            del self.containers[container["Name"].lstrip("/")]
        else:
            raise AssertionError("Unexpected docker command: " + str(args))
        return ""

    def create(self, name, payload):
        self.events.append(("create", name, copy.deepcopy(payload)))
        if name == self.fail_create:
            raise u.UpgradeError("create failed")
        container = fixture(name)
        container["Id"] = "new-" + name
        container["Image"] = "sha256:new-" + name
        container["Config"] = payload
        container["HostConfig"] = payload["HostConfig"]
        container["State"]["Running"] = False
        self.containers[name] = container
        return container["Id"]


class UpgradeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.names = ["trojan-panel", "trojan-panel-core", "trojan-panel-ui"]
        self.fake = FakeDocker(self.names, str(self.root / "data"))
        self.targets = [(name, "ghcr.io/electronlsr/" + name + ":2026.10.05-r1") for name in self.names]
        for name in self.names:
            path = self.root / "data" / name / "config"
            path.mkdir(parents=True)
            (path / "config.ini").write_text("[mysql]\nhost=127.0.0.1\nport=9507\nuser=root\npassword=secret\n")
        self.patchers = [patch.object(u, "Engine", return_value=self.fake), patch.object(u, "docker", self.fake.docker),
                         patch.object(u, "inspect", self.fake.inspect), patch.object(u, "wait_running", lambda name: None),
                         patch.object(u, "backup_database", lambda container, backup: self.fake.events.append(("db-backup",))),
                         patch.object(u, "backup_mounts", lambda containers, backup: self.fake.events.append(("mount-backup",)))]
        for patcher in self.patchers:
            patcher.start()
            self.addCleanup(patcher.stop)

    def execute(self):
        return u.upgrade(self.targets, str(self.root / "backups"))

    def assert_originals_running(self):
        for name in self.names:
            self.assertEqual(self.fake.containers[name]["Id"], "old-" + name)
            self.assertTrue(self.fake.containers[name]["State"]["Running"])
            self.assertEqual(self.fake.containers[name]["HostConfig"]["RestartPolicy"]["Name"], "always")

    def test_upgrade_preserves_data_options_and_retains_old(self):
        backup = self.execute()
        self.assertTrue((backup / "manifest.json").exists())
        self.assertEqual(backup.stat().st_mode & 0o777, 0o700)
        recovery = (backup / "RECOVERY.txt").read_text()
        self.assertLess(recovery.index("docker update --restart=no trojan-panel"), recovery.index("docker stop trojan-panel"))
        self.assertIn("tar --acls --xattrs -xzpf", recovery)
        events = [event[0] for event in self.fake.events]
        self.assertLess(max(i for i, kind in enumerate(events) if kind == "pull"), events.index("stop"))
        self.assertLess(events.index("db-backup"), events.index("stop"))
        self.assertLess(events.index("mount-backup"), events.index("create"))
        for name in self.names:
            old = [value for key, value in self.fake.containers.items() if key.startswith(name + ".pre-")][0]
            self.assertFalse(old["State"]["Running"])
            self.assertEqual(old["HostConfig"]["RestartPolicy"]["Name"], "no")
            new = self.fake.containers[name]
            self.assertEqual(new["Config"]["Env"], old["Config"]["Env"])
            self.assertEqual(new["HostConfig"]["Binds"], old["HostConfig"]["Binds"])
            self.assertEqual(new["HostConfig"]["RestartPolicy"]["Name"], "always")
        self.assertFalse(any(event[0] in ("rm", "rmi") for event in self.fake.events))

    def test_failed_pull_does_not_stop_or_mutate_containers(self):
        self.fake.fail_pull = self.targets[-1][1]
        with self.assertRaises(u.UpgradeError):
            self.execute()
        self.assert_originals_running()
        self.assertFalse(any(event[0] in ("stop", "update", "rename", "create", "rm") for event in self.fake.events))

    def test_failed_database_dump_does_not_stop_containers(self):
        with patch.object(u, "backup_database", side_effect=u.UpgradeError("dump failed")):
            with self.assertRaises(u.UpgradeError):
                self.execute()
        self.assert_originals_running()
        self.assertFalse(any(event[0] == "stop" for event in self.fake.events))

    def test_failed_mount_backup_restarts_originals(self):
        with patch.object(u, "backup_mounts", side_effect=u.UpgradeError("disk full")):
            with self.assertRaises(u.UpgradeError):
                self.execute()
        self.assert_originals_running()
        self.assertFalse(any(event[0] in ("create", "rm") for event in self.fake.events))

    def test_failed_create_rolls_back_previously_replaced_container(self):
        self.fake.fail_create = "trojan-panel-core"
        with self.assertRaises(u.UpgradeError):
            self.execute()
        self.assert_originals_running()
        removed = [event[-1] for event in self.fake.events if event[0] == "rm"]
        self.assertEqual(removed, ["new-trojan-panel"])

    def test_failed_start_rolls_back_without_removing_old_images(self):
        self.fake.fail_start = "new-trojan-panel-core"
        with self.assertRaises(u.UpgradeError):
            self.execute()
        self.assert_originals_running()
        self.assertFalse(any(event[0] == "rmi" for event in self.fake.events))

    def test_startup_crash_rolls_back_all(self):
        with patch.object(u, "wait_running", side_effect=u.UpgradeError("restart loop")):
            with self.assertRaises(u.UpgradeError):
                self.execute()
        self.assert_originals_running()

    def test_create_lost_response_recovers_transaction_labeled_container(self):
        original_create = self.fake.create
        def lost_response(name, payload):
            original_create(name, payload)
            raise u.UpgradeError("response lost after create")
        with patch.object(self.fake, "create", lost_response):
            with self.assertRaises(u.UpgradeError):
                self.execute()
        self.assert_originals_running()
        self.assertFalse(any(value["Id"].startswith("new-") for value in self.fake.containers.values()))

    def test_rename_lost_response_recovers_by_immutable_id(self):
        original_docker = self.fake.docker
        failed = [False]
        def lost_response(*args):
            result = original_docker(*args)
            if args[0] == "rename" and not failed[0]:
                failed[0] = True
                raise u.UpgradeError("response lost after rename")
            return result
        with patch.object(u, "docker", lost_response):
            with self.assertRaises(u.UpgradeError):
                self.execute()
        self.assert_originals_running()

    def test_restart_policy_update_lost_response_is_restored(self):
        original_docker = self.fake.docker
        failed = [False]
        def lost_response(*args):
            result = original_docker(*args)
            if args[:2] == ("update", "--restart=no") and not failed[0]:
                failed[0] = True
                raise u.UpgradeError("response lost after update")
            return result
        with patch.object(u, "docker", lost_response):
            with self.assertRaises(u.UpgradeError):
                self.execute()
        self.assert_originals_running()

    def test_failed_replacement_removal_does_not_start_old_writer(self):
        original_docker = self.fake.docker
        def removal_fails(*args):
            if args[0] == "rm":
                raise u.UpgradeError("daemon could not remove running replacement")
            return original_docker(*args)
        with patch.object(u, "docker", removal_fails), patch.object(u, "wait_running", side_effect=u.UpgradeError("check failed")):
            with self.assertRaises(u.UpgradeError):
                self.execute()
        original = self.fake.lookup("old-trojan-panel")
        self.assertFalse(original["State"]["Running"])
        self.assertEqual(original["HostConfig"]["RestartPolicy"]["Name"], "no")
        self.assertFalse(any(event == ("start", "old-trojan-panel") for event in self.fake.events))

    def test_daemon_uncertainty_during_rollback_does_not_start_old_writer(self):
        with patch.object(self.fake, "inspect_optional", side_effect=u.UpgradeError("daemon unavailable")), patch.object(u, "wait_running", side_effect=u.UpgradeError("check failed")):
            with self.assertRaises(u.UpgradeError):
                self.execute()
        self.assertFalse(any(event[0] == "start" and event[1].startswith("old-") for event in self.fake.events))

    def test_core_file_only_config_mount_rejected_before_stopping(self):
        container = self.fake.containers["trojan-panel-core"]
        container["Mounts"][0]["Source"] += "/config.ini"
        container["Mounts"][0]["Destination"] += "/config.ini"
        with self.assertRaisesRegex(u.UpgradeError, "config/sqlite"):
            self.execute()
        self.assert_originals_running()
        self.assertFalse(any(event[0] in ("stop", "update", "rename", "create") for event in self.fake.events))

    def test_core_tmpfs_state_rejected_before_mutation(self):
        container = self.fake.containers["trojan-panel-core"]
        container["Mounts"].append({"Type": "tmpfs", "Source": "", "Destination": "/tpdata/trojan-panel-core/config/sqlite"})
        with self.assertRaisesRegex(u.UpgradeError, "non-persistent"):
            self.execute()
        self.assert_originals_running()
        self.assertFalse(any(event[0] in ("stop", "update", "rename", "create") for event in self.fake.events))

    def test_same_upstream_version_still_upgrades_different_image(self):
        self.execute()
        self.assertEqual(sum(event[0] == "create" for event in self.fake.events), 3)

    def test_identical_image_skips_container_changes(self):
        for name, target in self.targets:
            self.fake.images[target]["Id"] = self.fake.containers[name]["Image"]
        self.assertIsNone(self.execute())
        self.assert_originals_running()
        self.assertFalse(any(event[0] in ("update", "stop", "create") for event in self.fake.events))

    def test_unsupported_schema_stops_before_mutation(self):
        with patch.object(u, "check_version", side_effect=u.UpgradeError("legacy schema")):
            with self.assertRaises(u.UpgradeError):
                self.execute()
        self.assert_originals_running()
        self.assertEqual(self.fake.events, [])


class PayloadTests(unittest.TestCase):
    def test_new_defaults_and_custom_settings(self):
        container = fixture()
        old = {"Config": copy.deepcopy(container["Config"])}
        new = {"Config": {"Entrypoint": ["/new-entrypoint"], "Cmd": ["serve"], "WorkingDir": "/tpdata/trojan-panel",
                          "Env": ["NEW_DEFAULT=yes", "mariadb_pas=wrong"], "Labels": {"org.opencontainers.image.version": "2026.10.05-r1"}}}
        payload = u.create_payload(container, old, new, "new:tag")
        self.assertEqual(payload["Entrypoint"], ["/new-entrypoint"])
        self.assertIn("mariadb_pas=secret with = signs", payload["Env"])
        self.assertIn("NEW_DEFAULT=yes", payload["Env"])
        self.assertNotIn("mariadb_pas=wrong", payload["Env"])
        self.assertEqual(payload["Labels"]["custom"], "keep")
        container["Config"]["Entrypoint"] = ["/custom-wrapper"]
        self.assertEqual(u.create_payload(container, old, new, "new:tag")["Entrypoint"], ["/custom-wrapper"])

    def test_anonymous_volume_keeps_existing_name(self):
        container = fixture()
        container["Mounts"].append({"Type": "volume", "Name": "keep-existing-volume", "Destination": "/state", "RW": True})
        payload = u.create_payload(container, {"Config": {}}, {"Config": {}}, "new:tag")
        self.assertIn("keep-existing-volume:/state:rw", payload["HostConfig"]["Binds"])

    def test_modern_anonymous_volume_keeps_inspected_source(self):
        container = fixture()
        container["HostConfig"]["Mounts"] = [{"Type": "volume", "Target": "/state"}]
        container["Mounts"].append({"Type": "volume", "Name": "modern-existing-volume", "Destination": "/state", "RW": True})
        payload = u.create_payload(container, {"Config": {}}, {"Config": {}}, "new:tag")
        self.assertEqual(payload["HostConfig"]["Mounts"][0]["Source"], "modern-existing-volume")

    def test_legacy_anonymous_volume_target_is_replaced(self):
        container = fixture()
        container["HostConfig"]["Binds"].append("/state")
        container["Mounts"].append({"Type": "volume", "Name": "legacy-existing-volume", "Destination": "/state", "RW": True})
        payload = u.create_payload(container, {"Config": {}}, {"Config": {}}, "new:tag")
        self.assertIn("legacy-existing-volume:/state:rw", payload["HostConfig"]["Binds"])
        self.assertNotIn("/state", payload["HostConfig"]["Binds"])

    def test_legacy_readonly_anonymous_volume_preserves_mode_once(self):
        container = fixture()
        container["HostConfig"]["Binds"].append("/state:ro")
        container["Mounts"].append({"Type": "volume", "Name": "readonly-volume", "Destination": "/state", "RW": False})
        payload = u.create_payload(container, {"Config": {}}, {"Config": {}}, "new:tag")
        binds = payload["HostConfig"]["Binds"]
        self.assertIn("readonly-volume:/state:ro", binds)
        self.assertEqual(sum(":/state:" in item for item in binds), 1)

    def test_config_resolves_most_specific_mount_including_file_bind(self):
        container = fixture()
        container["Mounts"].insert(0, {"Type": "bind", "Source": "/stale", "Destination": "/tpdata"})
        self.assertEqual(str(u.config_source(container)), "/tpdata/trojan-panel/config/config.ini")
        container["Mounts"].append({"Type": "bind", "Source": "/actual.ini", "Destination": "/tpdata/trojan-panel/config/config.ini"})
        self.assertEqual(str(u.config_source(container)), "/actual.ini")

    def test_log_survives_closed_terminal(self):
        with patch("builtins.print", side_effect=BrokenPipeError("terminal closed")):
            u.log("recovering", flush=True)

    def test_release_refs_match_locked_digests_in_script_and_compose(self):
        lock = json.loads((ROOT / "images.lock.json").read_text())
        shell = (ROOT / "install_script.sh").read_text().replace("${IMAGE_RELEASE}", lock["release"])
        compose = (ROOT / "docker-compose.yml").read_text()
        self.assertEqual(len(lock["platforms"]), 7)
        for release in lock["images"].values():
            reference = release["reference"]
            self.assertRegex(reference, r"@sha256:[a-f0-9]{64}$")
            self.assertIn(reference, shell)
            self.assertIn(reference, compose)

    def test_embedded_helper_exactly_matches_canonical(self):
        shell = (ROOT / "install_script.sh").read_text()
        embedded = shell.split("  python3 - \"$@\" <<'TP_SAFE_UPGRADE_PY'\n", 1)[1].split("TP_SAFE_UPGRADE_PY\n", 1)[0]
        self.assertEqual(embedded, (ROOT / "scripts/safe_upgrade.py").read_text())


class BackupTests(unittest.TestCase):
    def test_archive_includes_symlink_bind_target_and_content(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            actual = root / "actual-config"
            actual.mkdir()
            (actual / "config.ini").write_text("fake config")
            source = root / "config-link"
            source.symlink_to(actual, target_is_directory=True)
            backup = root / "backup"
            backup.mkdir()
            container = fixture()
            container["Mounts"] = [{"Type": "bind", "Source": str(source), "Destination": "/config"}]
            u.backup_mounts([container], backup)
            with tarfile.open(str(backup / "mounted-data.tar.gz")) as archive:
                self.assertTrue(archive.getmember(str(source).lstrip("/")).issym())
                content = archive.extractfile(str(actual / "config.ini").lstrip("/")).read()
                self.assertEqual(content, b"fake config")

    def test_database_dump_uses_actual_config_tcp_and_private_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "trojan-panel" / "config"
            config.mkdir(parents=True)
            (config / "config.ini").write_text("[mysql]\nhost=localhost\nport=9507\nuser=custom\npassword=p=a;ss#word\n")
            container = fixture(root=str(root))
            backup = root / "backup"
            backup.mkdir()
            calls = []
            def fake_run(args, **kwargs):
                calls.append((args, kwargs["env"]["MYSQL_PWD"]))
                kwargs["stdout"].write(b"-- non-empty simulated SQL dump\n")
            with patch.object(u.shutil, "which", return_value="/usr/bin/mariadb-dump"), patch.object(u, "run", fake_run):
                u.backup_database(container, backup)
            self.assertIn("--protocol=TCP", calls[0][0])
            self.assertIn("--port=9507", calls[0][0])
            self.assertEqual(calls[0][1], "p=a;ss#word")
            self.assertFalse(any("p=a;ss#word" in arg for arg in calls[0][0]))
            self.assertGreater((backup / "trojan_panel_db.sql").stat().st_size, 0)


if __name__ == "__main__":
    unittest.main()
