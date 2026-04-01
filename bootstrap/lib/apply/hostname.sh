# hostname.sh — Apply system hostname

set -Eeuo pipefail
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && echo "Must source init.sh first" >&2 && exit 1

apply_hostname() {
    [[ -z "$HOSTNAME" ]] && return

    _info "Setting hostname to: $HOSTNAME"
    _dry hostnamectl set-hostname "$HOSTNAME"
    _run hostnamectl set-hostname "$HOSTNAME" || true
}
