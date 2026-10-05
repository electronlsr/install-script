[中文](README_ZH.md)

<div align="center">
<a href="https://github.com/trojanpanel"><img src="https://github.com/trojanpanel/install-script/assets/46235235/bfc4f96a-e8b6-499d-956f-a9c212059294" alt="Trojan Panel" width="150" /></a>
<h1>Trojan Panel</h1>
<p>
<a href="https://github.com/trojanpanel/install-script/stargazers"><img src="https://img.shields.io/github/stars/trojanpanel/install-script" alt="GitHub stars"></a>
<a href="https://github.com/trojanpanel/install-script/forks"><img src="https://img.shields.io/github/forks/trojanpanel/install-script" alt="GitHub forks"></a>
<a href="https://github.com/trojanpanel/install-script/issues"><img src="https://img.shields.io/github/issues/trojanpanel/install-script" alt="GitHub issues"></a>
<a href="https://github.com/trojanpanel/install-script/releases"><img src="https://img.shields.io/github/v/release/trojanpanel/install-script" alt="GitHub release"></a>
<a href="https://hub.docker.com/r/jonssonyan/trojan-panel"><img src="https://img.shields.io/docker/pulls/jonssonyan/trojan-panel" alt="Docker pulls"></a>
</p>
<h3>Multi-user web administration panel supporting Xray/Trojan-Go/Hysteria/NaiveProxy</h3>
<a href="https://github.com/trojanpanel/install-script/assets/46235235/7ac2bba1-b442-442d-b48e-b52f92e0bad8"><img src="https://github.com/trojanpanel/install-script/assets/46235235/7ac2bba1-b442-442d-b48e-b52f92e0bad8" alt="Trojan Panel"/></a>
</div>

## electronlsr release 2026.10.05-r1

This fork installs the versioned `ghcr.io/electronlsr/trojan-panel`, `trojan-panel-core`, and `trojan-panel-ui` images. Historical standalone/archive scripts remain upstream legacy tools, not this release's upgrade path.

### Existing servers: use menu 26

Run the online script below as root, then select **26: SAFE UPGRADE all installed Panel components**. For a node-only server this upgrades only Core. Menus 8/9/10 upgrade UI/backend/Core separately. **Do not uninstall/reinstall, run Compose against an existing script installation, or choose fresh-install menus to upgrade.**

- Supported starting point: upstream backend/Core v2.3.0 or v2.3.1 and UI v2.3.0, plus this fork's v2.3.1/v2.3.0-based builds. Earlier/unknown schema versions stop before replacement; no historical SQL migrations run.
- Requires a local Docker Engine Unix socket, Python 3.6+, GNU tar, and enough disk space for old + new images and a mounted-data backup. Existing host-network deployments are the primary supported topology. The upgrade does not install packages, edit Docker/firewall settings, replace MariaDB/Redis or flush Redis.
- All selected images are pulled first. Image IDs decide whether an update is needed, even when upstream binary version strings match.
- Container names, inspected environment (including passwords), bind/named/anonymous mounts and runtime settings are carried forward. The new image's default startup command is used unless you customized it.
- Before replacement, backend upgrade creates a logical `trojan_panel_db` dump through an installed `mariadb-dump`/`mysqldump` client or the existing host-network `trojan-panel-mariadb` container. A failed backup aborts the upgrade. For a remote database without either client, install an appropriate database dump client first.
- Mounted data, configuration, certificates and Core's SQLite database are archived while selected application containers are stopped. Backups and `RECOVERY.txt` are saved under `/var/backups/trojan-panel/<timestamp>/`, root-only. These files contain secrets; keep a secure off-server copy. Node-only upgrades do not back up central MySQL: back it up on the backend host first.
- Old containers/images are retained under `.pre-<timestamp>` names with auto-restart disabled. A replacement/startup failure attempts to restore the original containers. **Container rollback does not undo MySQL/SQLite/configuration writes.** Database recovery requires a coordinated pause of all writers (including remote Core nodes), and restoring an older backup loses later writes. No automatic database restore is attempted.
- Ordinary terminal disconnects and interrupts trigger recovery. SIGKILL, host power loss or an unavailable Docker daemon may require manual recovery using the saved manifest; no rollback can be guaranteed after these events.
- Upgrade one server first, check panel login, subscriptions and real node traffic, then continue with the others. Startup checks are not an end-to-end proxy test. Do not prune retained containers/images until you no longer need rollback.

Fresh installs use the same versioned release images. The three app images support the architectures listed below; upstream database/reverse-proxy images have their own platform limits. This fork retains the upstream fresh-install setup choices; no broad security reconfiguration is included.

Exact multi-platform image digests, source commits and successful release workflows are recorded in [images.lock.json](images.lock.json). Installer CI separately pulls every platform anonymously.

### Installer checks

```shell
bash -n install_script.sh
python3 -m unittest discover -s tests -v
bash tests/test_installer.sh
```

These are static and mocked Docker tests. They do not run the root installer or touch a real deployment. `scripts/safe_upgrade.py` is embedded into the one-file installer; after editing it run `python3 scripts/embed_upgrade.py` and rerun the tests.

## Features

- Speed build: One-click installation of scripts, lowering the deployment threshold, and quickly building the system
- Globalization: System language support 中文/English/한국인/فارسی
- Multi-agent support: Node type supports Xray/Trojan-Go/Hysteria/NaiveProxy
- Distributed: The front-end and back-end are developed separately, reducing the coupling between modules, and can be
  freely combined and deployed on multiple servers
- Powerful: Support login registration/user management/node management/mail management/blacklist management/custom
  camouflage website/system Kanban, etc.
- What you see is what you get: Support multi-node management, automatic management of remote nodes, automatic
  application/renewal of certificates, editing nodes in the panel, remote service real-time modification of node
  configuration

## Recommended OS

OS: CentOS 7+ / Ubuntu 18+ / Debian 10+

CPU: linux/amd64 / linux/arm/v6 / linux/arm/v7 / linux/arm64 / linux/s390x / linux/ppc64le / linux/386

Memory: ≥ 1G

## Installation

- Online(recommended)

    ```shell
    curl -fsSL https://raw.githubusercontent.com/electronlsr/install-script/main/install_script.sh -o /tmp/trojan-panel-install.sh && bash /tmp/trojan-panel-install.sh
    ```

- Standalone

    ```shell
    source <(curl -L https://github.com/trojanpanel/install-script/raw/main/install_script_standalone.sh)
    ```

- [Install old version](README_ARCHIVE.md)

## Other

Telegram Channel: https://t.me/jonssonyan_channel

You can subscribe to my channel on YouTube: https://www.youtube.com/@jonssonyan

## Documentation

Visit [https://trojanpanel.github.io](https://trojanpanel.github.io) to view the full documentation

## Change Log

Visit [https://trojanpanel.github.io/change/change-log.html](https://trojanpanel.github.io/change/change-log.html) to view the full log

## Bugs & Issues

[Issues](https://github.com/electronlsr/install-script/issues)

## Thanks

- [trojan](https://github.com/trojan-gfw/trojan)
- [trojan-go](https://github.com/p4gefau1t/trojan-go)
- [Xray-core](https://github.com/XTLS/Xray-core)
- [hysteria](https://github.com/HyNetwork/hysteria)
- [naiveproxy](https://github.com/klzgrad/naiveproxy)

## Stargazers over time

[![Stargazers over time](https://starchart.cc/trojanpanel/install-script.svg)](https://github.com/trojanpanel/install-script)
