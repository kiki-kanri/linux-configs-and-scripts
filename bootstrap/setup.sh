#!/bin/bash
# setup.sh — Bootstrap entry point
# Detects OS and dispatches to the appropriate runner.
#
# Usage:
#   ./setup.sh                    # Interactive (will ask SSH port, hostname)
#   SSH_PORT=2222 ./setup.sh      # Non-interactive, custom SSH port
#   ./setup.sh --dry-run          # Show what would be done
#   ./setup.sh --help             # Show this help
#
# Environment variables:
#   SSH_PORT   SSH port (default: 22)
#   TIMEZONE   Timezone (default: Asia/Taipei)
#   LOCALE     Locale (default: en_US.UTF-8)
#   HOSTNAME   Machine hostname (default: prompt)
#   DRY_RUN    Set to 1 to preview without applying

set -Eeuo pipefail

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
  cat <<'EOF'
bootstrap/setup.sh — Linux system bootstrap

USAGE
  ./setup.sh [options]

OPTIONS
  --dry-run       Preview changes without applying
  --help          Show this help

ENVIRONMENT
  SSH_PORT        SSH port (default: 22)
  TIMEZONE        Timezone (default: Asia/Taipei)
  LOCALE          Locale (default: en_US.UTF-8)
  HOSTNAME        Machine hostname (default: interactive prompt)
  DRY_RUN=1       Same as --dry-run

EXAMPLES
  # Interactive setup
  ./setup.sh

  # Custom SSH port, non-interactive
  SSH_PORT=2222 ./setup.sh

  # Preview only
  ./setup.sh --dry-run

  # Pipe to bash (one-liner for new machines)
  curl -L https://.../bootstrap/setup.sh | bash -s -- --dry-run

EOF
}

# ── Parse args ────────────────────────────────────────────────────────────────
DRY_RUN="${DRY_RUN:-0}"
SSH_PORT="${SSH_PORT:-}"
TIMEZONE="${TIMEZONE:-Asia/Taipei}"
LOCALE="${LOCALE:-en_US.UTF-8}"
HOSTNAME="${HOSTNAME:-}"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h) show_help; exit 0 ;;
    *) ;;
  esac
done

export DRY_RUN SSH_PORT TIMEZONE LOCALE HOSTNAME

# ── OS detection ──────────────────────────────────────────────────────────────
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID}-${VERSION_ID}"
  else
    echo "unknown"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  local os
  os="$(detect_os)"
  local runner

  # Reset per-run env so each runner gets a clean state
  export DRY_RUN SSH_PORT TIMEZONE LOCALE HOSTNAME

  case "$os" in
    debian-*)
      runner="$(dirname "${BASH_SOURCE[0]}")/runners/debian.sh"
      ;;
    ubuntu-*)
      runner="$(dirname "${BASH_SOURCE[0]}")/runners/ubuntu.sh"
      ;;
    *)
      echo "[bootstrap] ERROR: Unsupported OS: $os" >&2
      echo "[bootstrap] Supported: Debian, Ubuntu" >&2
      exit 1
      ;;
  esac

  if [[ ! -x "$runner" ]]; then
    chmod +x "$runner"
  fi

  exec "$runner" "$@"
}

main "$@"
