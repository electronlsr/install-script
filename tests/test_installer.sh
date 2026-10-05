#!/usr/bin/env bash
# No Docker daemon, root action, network, package manager or production execution.
set -eu
cd "$(dirname "$0")/.."
TP_INSTALLER_TEST_MODE=1 source ./install_script.sh
init_var
[[ "$IMAGE_RELEASE" == 3.0.0 ]]
[[ "$trojan_panel_ui_latest_version" == v3.0.0 ]]
[[ "$trojan_panel_latest_version" == v3.0.0 ]]
[[ "$trojan_panel_core_latest_version" == v3.0.0 ]]
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
export TEST_DOCKER_LOG="$test_root/docker.log"
ECHO_TYPE=echo
# All paths for calls under test point to disposable data.
TP_DATA="$test_root/"
UI_NGINX_CONFIG="$test_root/ui.conf"
DOMAIN_FILE="$test_root/domain.lock"
CERT_PATH="$test_root/cert/"
printf custom_cert > "$DOMAIN_FILE"
ui_http_config() { printf 'preserved mock nginx' > "$UI_NGINX_CONFIG"; }
install_custom_cert() { :; }
# Distinguish installed container queries from post-install running queries.
docker() {
  printf '%s\n' "$*" >> "$TEST_DOCKER_LOG"
  case "$1" in
    pull) [[ "${FAIL_PULL:-0}" != 1 ]] ;;
    run) touch "$test_root/ran" ;;
    exec) : ;;
    ps)
      if [[ "$*" == *'status=running'* && -f "$test_root/ran" ]]; then printf 'mock-id'; fi
      ;;
    container)
      [[ "${EXISTING:-0}" == 1 ]] && return 0
      [[ "$*" == *'trojan-panel-core'* && "${CORE_ONLY:-0}" == 1 ]]
      ;;
    *) printf 'Unexpected Docker command in smoke test: %s\n' "$*" >&2; return 1 ;;
  esac
}
# Architecture aliases match the release's seven Linux manifests.
for pair in x86_64:amd64 i686:386 armv6l:arm/v6 armv7l:arm/v7 aarch64:arm64 ppc64le:ppc64le s390x:s390x; do
  test_arch="${pair%%:*}"
  arch() { printf '%s' "$test_arch"; }
  detect_arch
  [[ "$docker_platform" == "linux/${pair#*:}" ]]
done
unset -f arch
# Fresh UI uses pinned GHCR image and current mounts; no real Docker command runs.
printf '\n\n\n0\n' | install_trojan_panel_ui >/dev/null
grep -q 'pull ghcr.io/electronlsr/trojan-panel-ui:3.0.0' "$TEST_DOCKER_LOG"
grep -q 'run .*--name trojan-panel-ui .*ghcr.io/electronlsr/trojan-panel-ui:3.0.0' "$TEST_DOCKER_LOG"
rm "$test_root/ran"; : > "$TEST_DOCKER_LOG"
# Fresh Backend and Core use the correct images and preserve name/config mounts.
printf '\n\n\n\ndb-secret\n\n\nredis-secret\n' | install_trojan_panel >/dev/null
grep -q 'pull ghcr.io/electronlsr/trojan-panel:3.0.0' "$TEST_DOCKER_LOG"
! grep -qi flushall "$TEST_DOCKER_LOG"
rm "$test_root/ran"; : > "$TEST_DOCKER_LOG"
printf '\n\n\n\ndb-secret\ncustom_db\ncustom_table\n\n\nredis-secret\n\n' | install_trojan_panel_core >/dev/null
grep -q 'pull ghcr.io/electronlsr/trojan-panel-core:3.0.0' "$TEST_DOCKER_LOG"
grep -q 'account_table=custom_table' "$TEST_DOCKER_LOG"
grep -q 'database=custom_db' "$TEST_DOCKER_LOG"
rm "$test_root/ran"; : > "$TEST_DOCKER_LOG"
# Failed fresh pull must not run a container or report success.
FAIL_PULL=1
if printf '\n\n\n0\n' | install_trojan_panel_ui >/dev/null; then
  echo 'Fresh install falsely succeeded after failed pull' >&2; exit 1
fi
! grep -q '^run ' "$TEST_DOCKER_LOG"
unset FAIL_PULL
# Upgrade-all only selects installed components on node-only servers.
CORE_ONLY=1
safe_upgrade() { printf '%s\n' "$*" > "$test_root/upgrade.args"; }
update_all_installed
grep -qx "trojan-panel-core ${TROJAN_PANEL_CORE_IMAGE}" "$test_root/upgrade.args"
unset CORE_ONLY
# Main must not run dependency installers, touch config, or check OS for upgrade.
check_sys() { echo 'UNEXPECTED check_sys' >&2; return 1; }
depend_install() { echo 'UNEXPECTED depend_install' >&2; return 1; }
mkdir_tools() { echo 'UNEXPECTED mkdir_tools' >&2; return 1; }
clear() { :; }
CORE_ONLY=1
main <<<26 >/dev/null
grep -qx "trojan-panel-core ${TROJAN_PANEL_CORE_IMAGE}" "$test_root/upgrade.args"
# Menu 10 explicitly targets only Core, even on a server with other components.
main <<<10 >/dev/null
grep -qx "trojan-panel-core ${TROJAN_PANEL_CORE_IMAGE}" "$test_root/upgrade.args"
# Choosing fresh install on an existing deployment must stop before dependencies.
EXISTING=1
if main <<<3 >/dev/null; then echo 'Existing install was accepted as fresh install' >&2; exit 1; fi
printf 'Shell fresh-install, failed-pull, node-only upgrade and menu smoke tests passed.\n'
