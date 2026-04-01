# sysctl.sh — Apply kernel sysctl parameters

set -Eeuo pipefail
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && echo "Must source init.sh first" >&2 && exit 1

apply_sysctl() {
    local src="$BOOTSTRAP_CONF_DIR/sysctl.conf"
    local dest="/etc/sysctl.d/99-linux-configs.conf"

    if [[ ! -f "$src" ]]; then
        _info "No shared sysctl.conf, skipping"
        return
    fi

    _info "Applying sysctl parameters: $dest"
    _dry "Would render $src → $dest"
    _run render_to_file_mv "$src" "$dest"
    _run chmod 644 "$dest"
    _run sysctl -p "$dest" 2>/dev/null || true
}
