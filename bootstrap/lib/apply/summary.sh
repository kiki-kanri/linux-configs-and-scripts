# summary.sh — Bootstrap summary output

set -Eeuo pipefail
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && echo "Must source init.sh first" >&2 && exit 1

bootstrap_summary() {
  echo ""
  echo "=== Bootstrap Summary ==="
  echo "  SSH Port:    $SSH_PORT"
  echo "  Timezone:    $TIMEZONE"
  echo "  Locale:      $LOCALE"
  echo "  Hostname:    ${HOSTNAME:-<unchanged>}"
  echo "  Sysctl:      /etc/sysctl.d/99-linux-configs.conf"
  echo "  UFW:         enabled (deny incoming, SSH port $SSH_PORT)"
  echo "  Configs:     conf/shared/ + conf/$OS_ID/"
  echo "========================="
  echo ""
}
