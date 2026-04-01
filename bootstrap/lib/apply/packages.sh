# packages.sh — Apply base system packages

set -Eeuo pipefail
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && echo "Must source init.sh first" >&2 && exit 1
apply_base_packages() {
    _info "Installing base packages..."

    local pkgs=(
        bash-completion
        bsdmainutils
        ca-certificates
        curl
        cron
        direnv
        htop
        iftop
        iotop
        iputils-ping
        locales
        lsd
        lsof
        net-tools
        nmap
        rsync
        sudo
        tar
        tcpdump
        tmux
        tree
        ufw
        unzip
        vim
        wget
    )

    _dry "Would run: apt-get update"
    if ! _run apt-get update -qq; then
        _warn "apt-get update failed (network or apt lock), continuing anyway"
    fi

    for pkg in "${pkgs[@]}"; do
        if dpkg -l "$pkg" &>/dev/null; then
            _dry "(already installed) $pkg"
        else
            _info "  installing: $pkg"
            if ! _run apt-get install -y --no-install-recommends "$pkg" 2>/dev/null; then
                _warn "Failed to install $pkg, skipping"
            fi
        fi
    done
}
