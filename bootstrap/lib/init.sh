# init.sh — Bootstrap library initialization
# Must be sourced first before any other bootstrap lib files.

set -Eeuo pipefail

# ── Guard: only source once ─────────────────────────────────────────────────
[[ -n "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && return 0
_BOOTSTRAP_INIT_SOURCED=1

# ── Detect paths ──────────────────────────────────────────────────────────────
# BASH_SOURCE[0] = this file (init.sh under bootstrap/lib/)
# __dir of init.sh = bootstrap/lib/
# __parent of lib/ = bootstrap/
BOOTSTRAP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "$BOOTSTRAP_LIB_DIR/.." && pwd)"
BOOTSTRAP_CONF_DIR="$BOOTSTRAP_DIR/conf"

# Top-level lib/ — shared by both bootstrap and toolkit
SHARED_LIB_DIR="$(cd "$BOOTSTRAP_DIR/../lib" && pwd)"

# Top-level toolkit conf/ — NOT used by bootstrap, but kept as a reference alias
TOOLKIT_CONF_DIR="$(cd "$BOOTSTRAP_DIR/../toolkit/conf" && pwd)"

# ── Load shared libs (os detection, logging, etc.) ──────────────────────────
for _lib in "$SHARED_LIB_DIR"/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
done

# ── Load bootstrap lib: render ─────────────────────────────────────────────
source "$BOOTSTRAP_LIB_DIR/render.sh"

# ── Export for subshells / apply modules ────────────────────────────────────
export BOOTSTRAP_DIR BOOTSTRAP_CONF_DIR BOOTSTRAP_LIB_DIR SHARED_LIB_DIR

# ── Defaults ─────────────────────────────────────────────────────────────────
SSH_PORT="${SSH_PORT:-22}"
TIMEZONE="${TIMEZONE:-Asia/Taipei}"
LOCALE="${LOCALE:-en_US.UTF-8}"
HOSTNAME="${HOSTNAME:-}"
DRY_RUN="${DRY_RUN:-0}"
MANAGED_BY="bootstrap"

# ── Logging helpers ──────────────────────────────────────────────────────────
_C='\033[0m'  # reset
_R='\033[31m' # red (error)
_Y='\033[33m' # yellow (warn/dry)
_G='\033[32m' # green (success)
_B='\033[34m' # blue (info)
_W='\033[97m' # white

_info() { echo -e "${_B}[bootstrap]${_C} INFO:    $*"; }
_warn() { echo -e "${_Y}[bootstrap]${_C} WARN:    $*" >&2; }
_error() { echo -e "${_R}[bootstrap]${_C} ERROR:   $*" >&2; }
_success() { echo -e "${_G}[bootstrap]${_C} SUCCESS:  $*"; }

_dry() {
    [[ "$DRY_RUN" == "1" ]] && echo -e "${_Y}[bootstrap]${_C} DRY-RUN: $*"
}

_run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "${_Y}[bootstrap]${_C} WOULD RUN: $*"
    else
        "$@" || true
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
