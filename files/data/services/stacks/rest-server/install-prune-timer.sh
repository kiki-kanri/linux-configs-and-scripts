#!/usr/bin/env bash

# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Constants/Variables
readonly SYSTEMD_DIR='/etc/systemd/system'
readonly UNIT_NAME='rest-server-prune'

# Functions

# Deployed with the stack and run on its host, so the shared log library is not available.
log_success() {
    printf '[ OK ] %s\n' "$*"
}

# Run
main() {
    # ExecStart follows wherever the stack was copied to.
    cat >"${SYSTEMD_DIR}/${UNIT_NAME}.service" <<EOF
[Unit]
Description=Prune and check restic repositories of rest-server
Wants=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=${SCRIPT_DIR}/prune.sh
EOF

    cat >"${SYSTEMD_DIR}/${UNIT_NAME}.timer" <<'EOF'
[Unit]
Description=Run rest-server-prune daily

[Timer]
OnCalendar=*-*-* 06:30
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now "${UNIT_NAME}.timer"
    log_success "Enabled ${UNIT_NAME}.timer"
}

main "$@"
