# init.sh — Bootstrap library initialization
# Must be sourced first before any other bootstrap lib files.

set -Eeuo pipefail

# ── Guard: only source once ─────────────────────────────────────────────────
[[ -n "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && return 0
_BOOTSTRAP_INIT_SOURCED=1

# ── Detect paths ──────────────────────────────────────────────────────────────
# BASH_SOURCE[0] = this file (init.sh)
# __dir of init.sh = bootstrap/lib/
# __parent of lib/ = bootstrap/
_BOOTSTRAP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "$BOOTSTRAP_LIB_DIR/.." && pwd)"
CONF_DIR="$BOOTSTRAP_DIR/conf"
RUNNER_DIR="${BOOTSTRAP_RUNNER_DIR:-}"

# Shared libs: top-level lib/ used by both bootstrap and toolkit
SHARED_LIB_DIR="$(cd "$BOOTSTRAP_DIR/../lib" && pwd)"

# ── Load shared libs (os detection, logging, etc.) ──────────────────────────
for _lib in "$SHARED_LIB_DIR"/*.sh; do
  [[ -f "$_lib" ]] && source "$_lib"
done

# ── Load bootstrap lib: render ─────────────────────────────────────────────
source "$BOOTSTRAP_LIB_DIR/render.sh"

# ── Defaults ─────────────────────────────────────────────────────────────────
SSH_PORT="${SSH_PORT:-22}"
TIMEZONE="${TIMEZONE:-Asia/Taipei}"
LOCALE="${LOCALE:-en_US.UTF-8}"
HOSTNAME="${HOSTNAME:-}"
DRY_RUN="${DRY_RUN:-0}"
MANAGED_BY="bootstrap"

# ── Logging helpers ──────────────────────────────────────────────────────────
_info()   { echo "[bootstrap] INFO:    $*"; }
_warn()   { echo "[bootstrap] WARN:    $*" >&2; }
_error()  { echo "[bootstrap] ERROR:   $*" >&2; }
_success(){ echo "[bootstrap] SUCCESS:  $*"; }

_dry() {
  [[ "$DRY_RUN" == "1" ]] && echo "[bootstrap] DRY-RUN: $*"
}

_run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[bootstrap] WOULD RUN: $*"
  else
    "$@"
  fi
}

# ── Require root ──────────────────────────────────────────────────────────────
require_root() {
  [[ $EUID -eq 0 ]] && return 0
  _error "This script must be run as root"
  exit 1
}

# ── Idempotency marker ────────────────────────────────────────────────────────
MARKER_FILE="/var/lib/.linux-configs-and-scripts.bootstrap.applied"

is_applied() { [[ -f "$MARKER_FILE" ]]; }

mark_applied() {
  _dry "Would create $MARKER_FILE"
  _run touch "$MARKER_FILE"
}
