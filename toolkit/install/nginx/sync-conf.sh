#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

# Sync repo-managed nginx configuration into /etc/nginx, asking per changed file unless -y is given.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../../libs/common.sh"
source "${SCRIPT_DIR}/config.sh"

# Functions
show_diff() {
    local src="$1"
    local dest="$2"
    local -a diff_args=(-u --label "${dest}" --label "repo: ${src#"${REPO_ROOT}/"}")

    [[ -t 1 ]] && diff_args+=(--color=always)
    [[ -f "${dest}" ]] || dest=/dev/null
    # diff exits 1 when files differ, which is the expected case here.
    diff "${diff_args[@]}" "${dest}" "${src}" || (($? == 1))
}

# Lists snippets under public/ that the repo no longer ships; acme-generated ssls/<domain>.conf files are excluded.
list_unmanaged_snippets() {
    local file
    local -a unmanaged=()

    [[ -d "${NGINX_PREFIX}/public" ]] || return 0

    while IFS= read -r -d '' file; do
        [[ "${file}" == public/ssls/* || -f "${NGINX_CONF_SRC}/${file}" ]] && continue
        unmanaged+=("${file}")
    done < <(cd "${NGINX_PREFIX}" && find public -type f -print0 | sort -z)

    ((${#unmanaged[@]} > 0)) || return 0
    log_warn "Files not shipped by the repo; review manually: ${unmanaged[*]}"
}

# Run
main() {
    local assume_yes=false
    local file src dest
    local -a skipped=()

    while (($# > 0)); do
        case "$1" in
        -y) assume_yes=true ;;
        *)
            log_error "Unknown argument: $1"
            exit 2
            ;;
        esac
        shift
    done

    require_root
    install -d -m 755 "${NGINX_PREFIX}/conf.d"

    while IFS= read -r -d '' file; do
        src="${NGINX_CONF_SRC}/${file}"
        dest="${NGINX_PREFIX}/${file}"
        cmp -s "${src}" "${dest}" 2>/dev/null && continue

        if [[ "${assume_yes}" == false ]]; then
            show_diff "${src}" "${dest}"
            if ! confirm "Install ${dest}?"; then
                skipped+=("${dest}")
                continue
            fi
        fi

        install_file "${src}" "${dest}" 644
        log_info "Installed: ${dest}"
    done < <(cd "${NGINX_CONF_SRC}" && find . -type f ! -name .gitkeep -printf '%P\0' | sort -z)

    ((${#skipped[@]} == 0)) || log_warn "Skipped: ${skipped[*]}"
    list_unmanaged_snippets
    log_success "NGINX configuration synced: ${NGINX_PREFIX}"
}

main "$@"
