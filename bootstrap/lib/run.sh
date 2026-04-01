# run.sh — Bootstrap orchestration: load all libs and run apply sequence

set -Eeuo pipefail

# Derive BOOTSTRAP_LIB_DIR from this file's location (bootstrap/lib/run.sh)
BOOTSTRAP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BOOTSTRAP_LIB_DIR

# ── Load all bootstrap libs in dependency order ───────────────────────────────
# init.sh must be first (sets paths, defaults, logging, guard)
source "$BOOTSTRAP_LIB_DIR/init.sh"

# prompt.sh
source "$(dirname "${BASH_SOURCE[0]}")/prompt.sh"

# Apply modules
for _f in "$(dirname "${BASH_SOURCE[0]}")/apply"/*.sh; do
    [[ -f "$_f" ]] && source "$_f"
done

# ── Full apply sequence ────────────────────────────────────────────────────────
bootstrap_apply() {
    apply_base_packages
    apply_locale
    apply_timezone
    apply_hostname
    apply_sysctl
    apply_os_configs
    apply_motd
    apply_ufw
    mark_applied
    bootstrap_summary
    _success "Bootstrap complete! Reboot recommended."
}
