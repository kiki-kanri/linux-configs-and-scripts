# locale.sh — Apply system locale

set -Eeuo pipefail
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && echo "Must source init.sh first" >&2 && exit 1

apply_locale() {
    _info "Setting locale: $LOCALE"
    _dry sed -i "/$LOCALE/s/^# //" /etc/locale.gen
    _dry locale-gen "$LOCALE"
    _dry update-locale "LANG=$LOCALE" "LC_ALL=$LOCALE"
    _run locale-gen "$LOCALE" >/dev/null 2>&1 || true
    _run update-locale "LANG=$LOCALE" "LC_ALL=$LOCALE" 2>/dev/null || true
}
