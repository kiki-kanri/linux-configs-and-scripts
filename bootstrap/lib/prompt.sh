# prompt.sh — Interactive prompts for bootstrap

set -Eeuo pipefail

# ── Guard ─────────────────────────────────────────────────────────────────────
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] &&
    echo "prompt.sh: must be sourced after init.sh" >&2 && return 1

# ── prompt_ssh_port ──────────────────────────────────────────────────────────
prompt_ssh_port() {
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
    local hn=""
    read -r -p "[bootstrap] Hostname: " hn
    if [[ -n "$hn" ]]; then
        HOSTNAME="$hn"
    fi
}
