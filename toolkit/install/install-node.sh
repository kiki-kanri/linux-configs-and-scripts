#!/usr/bin/env bash
# Install or refresh Node.js via NodeSource.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

NODE_VERSION="26.x"
NODESOURCE_SETUP_URL="https://deb.nodesource.com/setup_${NODE_VERSION}"
force=false

while (($# > 0)); do
    case "$1" in
    -f)
        force=true
        shift
        ;;
    -*)
        log_error "Unknown option: $1"
        exit 1
        ;;
    *)
        log_error "Unexpected argument: $1"
        exit 1
        ;;
    esac
done

require_root
require_cmd apt-get bash curl

if command_exists node && [[ "${force}" == false ]]; then
    log_info "Node.js is already installed: $(node --version 2>/dev/null || printf 'version unknown')"
    log_info "Use -f to reinstall Node.js ${NODE_VERSION}."
else
    log_info "Setting up NodeSource repository for Node.js ${NODE_VERSION}..."
    curl -fsSL "${NODESOURCE_SETUP_URL}" | bash -

    log_info "Installing nodejs..."
    apt-get update
    apt-get install -y nodejs

    log_success "Node.js installed."
fi

log_info "Node version : $(node --version 2>/dev/null || printf 'N/A')"
log_info "npm version  : $(npm --version 2>/dev/null || printf 'N/A')"
log_info "pnpm version : $(pnpm --version 2>/dev/null || printf 'N/A')"

if command_exists npm; then
    log_info "Updating npm itself..."
    npm install -g npm@latest 2>/dev/null || log_warn "Could not update npm globally."
else
    log_warn "npm not found."
fi

log_info "Applying Node package-manager security config..."
"${REPO_ROOT}/toolkit/security/setup-node-package-security.sh"

log_success "Node.js setup complete."
