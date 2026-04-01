#!/bin/bash
# debian.sh — Bootstrap entry point for Debian
# Usage: ./runners/debian.sh

set -Eeuo pipefail

# OS identifiers (used by apply_os_configs)
OS_ID="debian"
OS_NAME="Debian"

# Tell init.sh where this runner lives (so it can derive BOOTSTRAP_DIR)
BOOTSTRAP_RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load bootstrap libs and run
source "$(dirname "${BASH_SOURCE[0]}")/../lib/run.sh"

main() {
  require_root

  _info "Bootstrap runner: $OS_NAME"
  _info "This will configure SSH, UFW, sysctl, shell, MOTD, locale, and timezone."
  echo ""

  prompt_ssh_port
  prompt_hostname

  echo ""
  _info "Configured values:"
  echo "  SSH_PORT=$SSH_PORT"
  echo "  TIMEZONE=$TIMEZONE"
  echo "  LOCALE=$LOCALE"
  echo "  HOSTNAME=$HOSTNAME"
  echo ""

  if [[ "$DRY_RUN" != "1" ]]; then
    read -r -p "Proceed with bootstrap? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      _info "Aborted."
      exit 0
    fi
  fi

  bootstrap_apply
}

main "$@"
