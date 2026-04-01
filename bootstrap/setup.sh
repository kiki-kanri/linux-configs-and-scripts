#!/bin/bash
# setup.sh — Bootstrap entry point
# Detects OS and dispatches to the appropriate runner.
#
# Usage:
#   ./setup.sh          # Interactive setup
#   ./setup.sh --help   # Show this help

set -Eeuo pipefail

show_help() {
    cat <<'EOF'
bootstrap/setup.sh — Linux system bootstrap (interactive)

USAGE
  ./setup.sh [options]

OPTIONS
  --help, -h      Show this help

EXAMPLES
  ./setup.sh          # Start interactive setup
  ./setup.sh --dry-run   Preview without applying

EOF
}

# ── Dry run flag (no env shortcut) ──────────────────────────────────────────
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help | -h)
        show_help
        exit 0
        ;;
    esac
done
export DRY_RUN

# ── OS detection ─────────────────────────────────────────────────────────────
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

    case "$os" in
    ubuntu-*)
        runner="$(dirname "${BASH_SOURCE[0]}")/runners/ubuntu.sh"
        ;;
    *)
        echo "[bootstrap] ERROR: Unsupported OS: $os" >&2
        echo "[bootstrap] Supported: Ubuntu" >&2
        exit 1
        ;;
    esac

    [[ -x "$runner" ]] || chmod +x "$runner"
    exec "$runner" "$@"
}

main "$@"
