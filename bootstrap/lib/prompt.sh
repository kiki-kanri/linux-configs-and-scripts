# prompt.sh — Interactive prompts for bootstrap

set -Eeuo pipefail

# ── Guard ─────────────────────────────────────────────────────────────────────
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] &&
    echo "prompt.sh: must be sourced after init.sh" >&2 && return 1

# ── TTY guard ─────────────────────────────────────────────────────────────────
# If stdin is not a TTY and values are unset, skip prompts (non-interactive mode)
_is_interactive() {
    [[ -t 0 ]]
}

# ── prompt_ssh_port ──────────────────────────────────────────────────────────
prompt_ssh_port() {
    # Already set via environment — skip
    [[ -n "$SSH_PORT" ]] && return

    # Non-interactive (e.g. piped curl): use default
    if ! _is_interactive; then
        _info "Non-interactive mode: using default SSH_PORT=22"
        SSH_PORT="22"
        return
    fi

    local port=""
    while true; do
        read -r -p "[bootstrap] SSH port [22]: " port
        port="${port:-22}"
        if [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
            break
        fi
        _warn "Invalid port: $port (must be 1-65535)"
    done
    SSH_PORT="$port"
}

# ── prompt_hostname ───────────────────────────────────────────────────────────
prompt_hostname() {
    # Already set via environment — skip
    [[ -n "$HOSTNAME" ]] && return

    # Non-interactive: skip
    _is_interactive || return

    local hn=""
    read -r -p "[bootstrap] Hostname: " hn
    if [[ -n "$hn" ]]; then
        HOSTNAME="$hn"
    fi
}
