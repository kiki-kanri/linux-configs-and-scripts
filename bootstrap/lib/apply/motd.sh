# motd.sh — Apply custom MOTD

set -Eeuo pipefail
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && echo "Must source init.sh first" >&2 && exit 1

apply_motd() {
    local src="$BOOTSTRAP_CONF_DIR/motd.conf"
    local dest="/etc/update-motd.d/9999-linux-configs"

    if [[ ! -f "$src" ]]; then
        _info "No shared motd.conf, skipping"
        return
    fi

    _info "Applying custom MOTD: $dest"
    _run rm -f /etc/update-motd.d/9999-cat 2>/dev/null || true
    _dry "Would render $src → $dest"
    _run render_to_file_mv "$src" "$dest"
    _run chmod +x "$dest"
}
