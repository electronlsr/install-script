#!/usr/bin/env python3
"""Non-destructive upgrade of existing upstream Trojan Panel Docker containers.

Embedded verbatim in install_script.sh by scripts/embed_upgrade.py. No dependencies
beyond Python 3.6+, Docker CLI and tar. Never run this on a production host in tests.
"""
import configparser
import copy
import datetime
import fcntl
import http.client
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.parse


def log(message, **kwargs):
    try:
        print(message, **kwargs)
    except OSError:
        pass  # A closed terminal must never interrupt container recovery.


class UpgradeError(Exception):
    pass


def run(args, **kwargs):
    try:
        result = subprocess.run(args, stdout=kwargs.pop("stdout", subprocess.PIPE),
                                stderr=subprocess.PIPE, **kwargs)
    except OSError as error:
        raise UpgradeError("{} could not run: {}".format(args[0], error))
    if result.returncode:
        # Do not echo command arguments: Docker exec may contain database secrets.
        raise UpgradeError("{} failed: {}".format(args[0], result.stderr.decode(errors="replace").strip()))
    return result.stdout.decode().strip() if result.stdout is not None else ""


def docker(*args):
    return run(["docker"] + list(args))


def inspect(name, kind="container"):
    return json.loads(docker(kind, "inspect", name))[0]


class UnixHTTPConnection(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__("localhost", timeout=90)
        self.path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.path)


class Engine:
    def __init__(self):
        host = os.environ.get("DOCKER_HOST")
        if not host or os.environ.get("DOCKER_CONTEXT"):
            host = docker("context", "inspect", "--format", "{{.Endpoints.docker.Host}}")
        if not host.startswith("unix://"):
            raise UpgradeError("Upgrade requires the local Docker Unix socket; remote contexts are not supported.")
        self.socket = host[7:]
        self.prefix = ""
        self.prefix = "/v" + self.request("GET", "/version")["ApiVersion"]

    def request(self, method, path, body=None, missing_ok=False):
        connection = UnixHTTPConnection(self.socket)
        payload = json.dumps(body).encode() if body is not None else None
        try:
            connection.request(method, self.prefix + path, payload, {"Content-Type": "application/json"})
            response = connection.getresponse()
            data = response.read()
            if response.status == 404 and missing_ok:
                return None
            if response.status >= 300:
                # Server error may repeat config values, so avoid printing raw request data.
                raise UpgradeError("Docker API {} {} failed (HTTP {}).".format(method, path, response.status))
            return json.loads(data) if data else {}
        except (OSError, http.client.HTTPException, ValueError) as error:
            raise UpgradeError("Docker API connection/response failed: " + str(error))
        finally:
            connection.close()

    def inspect_optional(self, name):
        return self.request("GET", "/containers/" + urllib.parse.quote(name, safe="") + "/json", missing_ok=True)

    def create(self, name, payload):
        path = "/containers/create?name=" + urllib.parse.quote(name, safe="")
        return self.request("POST", path, payload)["Id"]


def create_payload(container, old_image, new_image, target):
    """Preserve user settings, while allowing changed image startup defaults."""
    config = copy.deepcopy(container["Config"])
    old_defaults = old_image.get("Config", {})
    new_defaults = new_image.get("Config", {})
    for field in ("Entrypoint", "Cmd", "WorkingDir", "User", "Healthcheck", "StopSignal", "Shell"):
        if config.get(field) == old_defaults.get(field):
            if field in new_defaults:
                config[field] = copy.deepcopy(new_defaults[field])
            else:
                config.pop(field, None)
    config["Image"] = target
    old_env = config.get("Env") or []
    keys = {item.split("=", 1)[0] for item in old_env}
    config["Env"] = old_env + [item for item in new_defaults.get("Env", []) if item.split("=", 1)[0] not in keys]
    if config.get("Hostname") == container["Id"][:12]:
        config.pop("Hostname", None)
    labels = copy.deepcopy(config.get("Labels") or {})
    for key, value in (new_defaults.get("Labels") or {}).items():
        if key.startswith("org.opencontainers.image."):
            labels[key] = value
    config["Labels"] = labels
    host = copy.deepcopy(container["HostConfig"])
    if host.get("AutoRemove"):
        raise UpgradeError("AutoRemove containers are not supported; no containers were changed.")
    # Preserve anonymous volumes from both legacy -v and modern --mount syntax.
    volumes = {item["Destination"]: item for item in container.get("Mounts", []) if item["Type"] == "volume"}
    for mount in host.get("Mounts") or []:
        if mount.get("Type") == "volume" and not mount.get("Source"):
            prior = volumes.get(mount["Target"])
            if not prior:
                raise UpgradeError("Cannot resolve anonymous volume: " + mount["Target"])
            mount["Source"] = prior["Name"]
    if host.get("Binds"):
        binds = []
        for item in host["Binds"]:
            parts = item.split(":")
            if parts[0] in volumes and (len(parts) == 1 or (len(parts) == 2 and not parts[1].startswith("/"))):
                mode = parts[1] if len(parts) == 2 else ("rw" if volumes[parts[0]]["RW"] else "ro")
                item = "{}:{}:{}".format(volumes[parts[0]]["Name"], parts[0], mode)
            binds.append(item)
        host["Binds"] = binds
    destinations = {item.split(":")[1] for item in host.get("Binds") or [] if ":" in item}
    destinations.update(item.get("Target") for item in host.get("Mounts") or [])
    for mount in container.get("Mounts", []):
        if mount["Type"] == "volume" and mount["Destination"] not in destinations:
            host.setdefault("Binds", [])
            if host["Binds"] is None:
                host["Binds"] = []
            host["Binds"].append("{}:{}:{}".format(mount["Name"], mount["Destination"], "rw" if mount["RW"] else "ro"))
    config["HostConfig"] = host
    if host.get("NetworkMode") not in ("host", "none"):
        endpoints = {}
        for name, endpoint in container.get("NetworkSettings", {}).get("Networks", {}).items():
            endpoints[name] = {key: copy.deepcopy(endpoint[key]) for key in ("IPAMConfig", "Links", "Aliases", "DriverOpts") if endpoint.get(key)}
        if endpoints:
            config["NetworkingConfig"] = {"EndpointsConfig": endpoints}
    return config


def mounted_source(container, filename):
    # Nested mounts override parents; an exact file bind overrides its directory.
    mounts = sorted(container.get("Mounts", []), key=lambda mount: len(mount["Destination"].rstrip("/")), reverse=True)
    for mount in mounts:
        destination = mount["Destination"].rstrip("/")
        if filename == destination or filename.startswith(destination + "/"):
            if mount["Type"] not in ("bind", "volume") or not mount.get("Source"):
                raise UpgradeError("{} is covered by a non-persistent mount; manual migration is required.".format(filename))
            if filename == destination:
                return Path(mount["Source"])
            return Path(mount["Source"]) / filename[len(destination):].lstrip("/")
    raise UpgradeError("{} does not persist {} in a mount; manual migration is required.".format(container["Name"], filename))


def working_directory(container):
    return (container.get("Config", {}).get("WorkingDir") or "/tpdata/" + container["Name"].lstrip("/")).rstrip("/")


def config_source(container):
    return mounted_source(container, working_directory(container) + "/config/config.ini")


def backup_database(container, backup):
    config = configparser.ConfigParser(interpolation=None, inline_comment_prefixes=None)
    if not config.read(str(config_source(container))):
        raise UpgradeError("Cannot read the backend config.ini for a database backup.")
    try:
        connection = config["mysql"]
        env = dict(os.environ, MYSQL_PWD=connection["password"])
        args = ["--protocol=TCP", "--host=" + connection["host"], "--port=" + connection["port"],
                "--user=" + connection["user"], "--single-transaction", "--quick",
                "--routines", "--events", "--triggers", "--hex-blob", "--databases", "trojan_panel_db"]
    except KeyError:
        raise UpgradeError("Incomplete mysql settings in config.ini; database backup is required.")
    client = shutil.which("mariadb-dump") or shutil.which("mysqldump")
    if client:
        command = [client] + args
    else:
        # Use the already-installed database container; do not change its version/data.
        try:
            db = inspect("trojan-panel-mariadb")
        except UpgradeError:
            raise UpgradeError("Database backup requires a running trojan-panel-mariadb container or a local mariadb-dump/mysqldump client. No containers changed.")
        if not db["State"]["Running"] or db["HostConfig"].get("NetworkMode") != "host":
            raise UpgradeError("Install a local mariadb-dump client for this database topology; no containers changed.")
        command = ["docker", "exec", "-e", "MYSQL_PWD", "trojan-panel-mariadb", "mysqldump"] + args
    filename = backup / "trojan_panel_db.sql"
    with filename.open("wb") as output:
        run(command, stdout=output, env=env)
    if filename.stat().st_size == 0:
        raise UpgradeError("Database dump was empty; no containers changed.")


def backup_mounts(containers, backup):
    sources = set()
    for container in containers:
        for mount in container.get("Mounts", []):
            if mount["Type"] in ("bind", "volume") and mount["Source"] != "/etc/localtime":
                path = os.path.abspath(mount["Source"])
                if not os.path.exists(path):
                    raise UpgradeError("Missing mount source: " + path)
                if path == "/" or os.path.commonpath([str(backup), path]) == path:
                    raise UpgradeError("Backup path must not be inside a container mount: " + path)
                sources.add(path)
                # A bind source itself can be a symlink. Archive both the link
                # and its target; tar otherwise saves only the link, not the data.
                if os.path.islink(path):
                    resolved = os.path.realpath(path)
                    if resolved == "/" or os.path.commonpath([str(backup), resolved]) == resolved:
                        raise UpgradeError("Unsafe backup location relative to symlinked mount: " + path)
                    sources.add(resolved)
    # Remove nested duplicates. GNU tar preserves ownership, modes, ACLs and xattrs.
    roots = [path for path in sorted(sources) if not any(path.startswith(parent + "/") for parent in sources if parent != path)]
    if roots:
        run(["tar", "--acls", "--xattrs", "--numeric-owner", "-czpf", str(backup / "mounted-data.tar.gz"),
             "-C", "/", "--"] + [path.lstrip("/") for path in roots])


def restart_value(container):
    policy = container["HostConfig"].get("RestartPolicy") or {}
    value = policy.get("Name") or "no"
    if value == "on-failure" and policy.get("MaximumRetryCount"):
        value += ":" + str(policy["MaximumRetryCount"])
    return value


def wait_running(name, timeout=45):
    deadline = time.monotonic() + timeout
    stable = 0
    while time.monotonic() < deadline:
        current = inspect(name)
        state = current["State"]
        if not state.get("Running") or state.get("Restarting") or current.get("RestartCount", 0):
            raise UpgradeError(name + " stopped or restarted during startup.")
        health = state.get("Health", {}).get("Status")
        if health == "unhealthy":
            raise UpgradeError(name + " failed its image health check.")
        stable = stable + 1 if health in (None, "healthy") else 0
        if stable >= 5:
            return
        time.sleep(2)
    raise UpgradeError(name + " did not become ready before timeout.")


def check_version(name):
    if name == "trojan-panel-ui":
        version = docker("exec", name, "cat", "/tpdata/trojan-panel-ui/version")
        compatible = version == "v2.3.0" or version.startswith("v2.3.0-")
    else:
        version = docker("exec", name, "./" + name, "-version")
        compatible = version in ("v2.3.0", "v2.3.1") or version.startswith("v2.3.1-")
    if not compatible:
        raise UpgradeError("{} reports unsupported schema version {}. Upgrade older installations separately; no legacy SQL is run here.".format(name, version))


def write_recovery(backup, records):
    manifest = {"created_at": datetime.datetime.utcnow().isoformat() + "Z", "containers": records}
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    lines = ["Trojan Panel upgrade recovery", "", "This directory contains passwords and private keys. Keep it root-only and copy it securely off-host.",
             "Old containers and their images are retained. Database/Redis containers were not replaced or flushed.",
             "Container rollback does NOT roll back MySQL, SQLite or configuration writes. Do not restore an old SQL dump into a live deployment.",
             "Before data recovery stop ALL writers, including Core nodes on other servers. Restoring a snapshot discards later writes.",
             "mounted-data.tar.gz paths are relative to /. Review the archive before restoring with tar --acls --xattrs -xzpf <archive> -C /.",
             "trojan_panel_db.sql is a logical single-transaction database snapshot when backend was selected. Keep database credentials private.",
             "For a node-only upgrade, the central MySQL database is NOT backed up here. Back it up on the backend host first.",
             "", "For container-only rollback, first review actual container names/states with docker ps -a. Then, for each upgraded component:"]
    for record in records:
        lines += ["", "# " + record["name"], "docker update --restart=no " + record["name"], "docker stop " + record["name"],
                  "docker rename {} {}.failed".format(record["name"], record["old_name"]),
                  "docker rename {} {}".format(record["old_name"], record["name"]),
                  "docker update --restart={} {}".format(record["restart"], record["name"]),
                  "docker start " + record["name"]]
    lines += ["", "After functional verification, remove retained old containers manually only when rollback is no longer needed.",
              "Do not use docker system prune or image prune while relying on rollback containers."]
    (backup / "RECOVERY.txt").write_text("\n".join(lines) + "\n")


def upgrade(targets, backup_root="/var/backups/trojan-panel"):
    engine = Engine()
    snapshots = []
    for name, target in targets:
        container = inspect(name)
        if not container["State"]["Running"]:
            raise UpgradeError(name + " is not running; investigate it before upgrading.")
        old_image = inspect(container["Image"], "image")
        check_version(name)
        log("Pulling {} before touching {}...".format(target, name), flush=True)
        docker("pull", target)
        new_image = inspect(target, "image")
        if container["Image"] == new_image["Id"]:
            log(name + " already runs this image.", flush=True)
            continue
        payload = create_payload(container, old_image, new_image, target)
        if name != "trojan-panel-ui":
            config_source(container)
        if name == "trojan-panel-core":
            # A config.ini-only mount is insufficient: SQLite and its journal
            # must survive replacement, so require its whole directory persisted.
            mounted_source(container, working_directory(container) + "/config/sqlite")
        snapshots.append((name, container, payload))
    if not snapshots:
        log("All selected containers are current.")
        return None
    stamp = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%S") + "-" + str(os.getpid())
    backup = Path(backup_root).resolve() / stamp
    backup.mkdir(mode=0o700, parents=True, exist_ok=False)
    os.chmod(str(backup), 0o700)
    records = [{"name": name, "old_name": name + ".pre-" + stamp,
                "restart": restart_value(container), "inspect": container, "new_image": payload["Image"]}
               for name, container, payload in snapshots]
    write_recovery(backup, records)
    log("Backup and recovery instructions: " + str(backup), flush=True)
    for name, container, payload in snapshots:
        if name == "trojan-panel":
            backup_database(container, backup)
    transaction_label = "io.electronlsr.trojan-panel.upgrade"
    for _, _, payload in snapshots:
        payload["Labels"][transaction_label] = stamp
    try:
        for record in records:
            docker("update", "--restart=no", record["name"])
            docker("stop", "--time", "30", record["name"])
        backup_mounts([item[1] for item in snapshots], backup)
        for record, (_, container, payload) in zip(records, snapshots):
            docker("rename", record["name"], record["old_name"])
            new_id = engine.create(record["name"], payload)
            docker("start", new_id)
            wait_running(record["name"])
    except BaseException:
        # A second terminal disconnect/interrupt must not abort recovery halfway.
        saved_handlers = {sig: signal.signal(sig, signal.SIG_IGN) for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)}
        log("Upgrade failed. Restoring original container names and restart policies...", file=sys.stderr, flush=True)
        errors = []
        # All old containers stay intact. Never delete an old container or its image.
        safe_to_restart = []
        # Reinspect immutable old IDs and transaction labels, including a Docker
        # operation that succeeded on the daemon but lost its response to the CLI.
        for record in reversed(records):
            try:
                candidate = engine.inspect_optional(record["name"])
                if candidate and candidate["Id"] != record["inspect"]["Id"]:
                    if candidate.get("Config", {}).get("Labels", {}).get(transaction_label) != stamp:
                        raise UpgradeError("Unexpected container owns " + record["name"] + "; it was left untouched.")
                    docker("rm", "-f", candidate["Id"])
                    if engine.inspect_optional(record["name"]) is not None:
                        raise UpgradeError("Replacement still exists: " + record["name"])
                original = inspect(record["inspect"]["Id"])
                actual_name = original["Name"].lstrip("/")
                if actual_name != record["name"]:
                    docker("rename", actual_name, record["name"])
                safe_to_restart.append(record)
            except UpgradeError as error:
                # Do not restart an old writer when a replacement might still run.
                errors.append(str(error) + " Original remains stopped/disabled; inspect manually.")
        for record in safe_to_restart:
            try:
                old_id = record["inspect"]["Id"]
                docker("update", "--restart=" + record["restart"], old_id)
                docker("start", old_id)
            except UpgradeError as error:
                errors.append(str(error))
        for sig, handler in saved_handlers.items():
            signal.signal(sig, handler)
        log("Database/configuration writes were NOT rewound. Review " + str(backup / "RECOVERY.txt"), file=sys.stderr)
        if errors:
            log("Rollback needs manual attention: " + "; ".join(errors), file=sys.stderr)
        raise
    log("Updated containers passed startup checks. Verify login, subscriptions and node traffic before upgrading other servers.")
    log("Old containers/images retained; backup: " + str(backup))
    log("Startup checks are not an end-to-end traffic test. Container rollback cannot undo database/configuration writes.")
    return backup


def main():
    if os.geteuid() != 0:
        raise UpgradeError("Run this installer as root on the server being upgraded.")
    os.umask(0o077)
    # Prevent competing upgrade invocations from stopping/renaming the same containers.
    with open("/var/lock/trojan-panel-upgrade.lock", "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise UpgradeError("Another Trojan Panel upgrade is running.")
        if len(sys.argv) < 3 or len(sys.argv) % 2 != 1:
            raise UpgradeError("Expected pairs of container name and image reference.")
        targets = list(zip(sys.argv[1::2], sys.argv[2::2]))
        def interrupted(signum, frame):
            raise UpgradeError("Upgrade interrupted; recovering original containers.")
        signal.signal(signal.SIGTERM, interrupted)
        signal.signal(signal.SIGHUP, interrupted)
        upgrade(targets)


if __name__ == "__main__":
    try:
        main()
    except (UpgradeError, OSError, ValueError, KeyError, KeyboardInterrupt) as error:
        log("ERROR: " + str(error), file=sys.stderr)
        sys.exit(1)
