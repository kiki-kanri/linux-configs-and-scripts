# ufw.sh — Configure UFW firewall

set -Eeuo pipefail
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && echo "Must source init.sh first" >&2 && exit 1

apply_ufw() {
  _info "Configuring UFW (SSH port $SSH_PORT)..."

  _dry "Would sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw"
  _run sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw 2>/dev/null || true

  _dry "Would ufw --force default deny incoming"
  _run ufw --force default deny incoming 2>/dev/null || true
  _dry "Would ufw --force default allow outgoing"
  _run ufw --force default allow outgoing 2>/dev/null || true

  _dry "Would ufw allow $SSH_PORT/tcp comment ssh"
  _run ufw allow "$SSH_PORT/tcp" comment ssh 2>/dev/null || true

  _dry "Would ufw --force enable"
  _run echo "y" | ufw --force enable 2>/dev/null || true
}
