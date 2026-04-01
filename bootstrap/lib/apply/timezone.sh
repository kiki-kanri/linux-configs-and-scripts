# timezone.sh — Apply system timezone

set -Eeuo pipefail
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && echo "Must source init.sh first" >&2 && exit 1

apply_timezone() {
  _info "Setting timezone: $TIMEZONE"
  if timedatectl list-timezones 2>/dev/null | grep -qx "$TIMEZONE"; then
    _dry timedatectl set-timezone "$TIMEZONE"
    _run timedatectl set-timezone "$TIMEZONE" 2>/dev/null || true
  else
    _warn "Unknown timezone: $TIMEZONE, skipping"
  fi
}
