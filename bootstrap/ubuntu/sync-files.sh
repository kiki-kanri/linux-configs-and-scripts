#!/bin/bash
# Sync bootstrap-managed files to an already-configured Ubuntu host.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P -- "${SCRIPT_DIR}/../.." && pwd)"
FILES_DIR="${SCRIPT_DIR}/files"

# shellcheck disable=SC1091
source "${REPO_ROOT}/libs/common.sh"

DRY_RUN=false
SYNC_HOME_DIRS=true
FORCE_SENSITIVE=false
SKIP_SENSITIVE=false
VERBOSE="${VERBOSE:-0}"

usage() {
    cat <<'USAGE'
Usage: sudo bootstrap/ubuntu/sync-files.sh [options]

Sync files from bootstrap/ubuntu/files into the live system after this repo has
been updated with git pull. Non-sensitive managed files are overwritten when
changed. Sensitive package-manager config files prompt before overwrite.

Options:
  -y, --yes              overwrite sensitive files without prompting
      --skip-sensitive   never overwrite changed sensitive files
      --no-home-sync     update /etc, /root, and /scripts only; skip /home/*
      --dry-run          show what would change without writing files
  -v, --verbose          print unchanged file checks too
  -h, --help             show this help

Examples:
  sudo git -C /scripts/linux-configs-and-scripts pull
  cd /scripts/linux-configs-and-scripts
  sudo bootstrap/ubuntu/sync-files.sh
  sudo bootstrap/ubuntu/sync-files.sh --yes
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -y | --yes) FORCE_SENSITIVE=true ;;
    --skip-sensitive) SKIP_SENSITIVE=true ;;
    --no-home-sync) SYNC_HOME_DIRS=false ;;
    --dry-run) DRY_RUN=true ;;
    -v | --verbose) VERBOSE=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        log_error "Unknown option: $1"
        usage >&2
        exit 2
        ;;
    esac
    shift
done

if "${FORCE_SENSITIVE}" && "${SKIP_SENSITIVE}"; then
    log_error '--yes and --skip-sensitive cannot be used together.'
    exit 2
fi

require_root
require_cmd basename chown chmod cmp cp dirname find install mkdir sort stat
require_dir "${FILES_DIR}"

is_sensitive_path() {
    local path="$1"

    case "${path}" in
    */.npmrc | */npmrc | */.bunfig.toml | */bunfig.toml | */.config/pnpm/rc | */pnpm/rc) return 0 ;;
    esac

    return 1
}

is_never_sync_path() {
    local path="$1"

    case "${path}" in
    /etc/ssh/sshd_config | /root/.bashrc | /root/.profile | /home/*/.bashrc | /home/*/.profile) return 0 ;;
    esac

    return 1
}

mode_for_path() {
    local dest="$1"
    local src="$2"

    case "${dest}" in
    /scripts/*.sh) printf '700\n' ;;
    /etc/profile.d/*.sh) printf '644\n' ;;
    /etc/bash.bashrc | /etc/profile | /etc/npmrc | /etc/pnpm/rc | /etc/bun/bunfig.toml | /etc/vim/vimrc) printf '644\n' ;;
    /etc/skel/.bashrc | /etc/skel/.profile | /etc/skel/.npmrc | /etc/skel/.bunfig.toml | /etc/skel/.config/*) printf '600\n' ;;
    /home/*/.bashrc | /home/*/.profile | /home/*/.npmrc | /home/*/.bunfig.toml | /home/*/.config/*) printf '600\n' ;;
    /root/.bashrc | /root/.profile | /root/.npmrc | /root/.bunfig.toml | /root/.config/*) printf '600\n' ;;
    *) stat -c '%a' "${src}" ;;
    esac
}

ensure_parent_dir() {
    local dest="$1"
    local owner="$2"
    local parent

    parent="$(dirname -- "${dest}")"
    if "${DRY_RUN}"; then
        [[ -d "${parent}" ]] || log_info "Would create directory: ${parent}"
        return 0
    fi

    install -d -m 755 "${parent}"
    case "${parent}" in
    /root/.config | /root/.config/* | /home/*/.config | /home/*/.config/* | /etc/skel/.config | /etc/skel/.config/*)
        chown "${owner}" "${parent}"
        chmod 700 "${parent}"
        ;;
    /etc/pnpm | /etc/bun | /scripts)
        chown root:root "${parent}"
        chmod 755 "${parent}"
        ;;
    esac
}

should_write_file() {
    local src="$1"
    local dest="$2"

    if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
        log_debug "Unchanged content: ${dest}"
        return 1
    fi

    if ! is_sensitive_path "${dest}" || "${FORCE_SENSITIVE}"; then
        return 0
    fi

    if "${SKIP_SENSITIVE}"; then
        log_warn "Skipping sensitive file content: ${dest}"
        return 1
    fi

    if [[ -e "${dest}" ]]; then
        if "${DRY_RUN}"; then
            log_info "Would prompt before overwriting sensitive file: ${dest}"
            return 1
        fi

        confirm "Overwrite sensitive file ${dest}?" --default=no && return 0
        log_warn "Skipping sensitive file content: ${dest}"
        return 1
    fi

    return 0
}

metadata_needs_update() {
    local dest="$1"
    local owner="$2"
    local mode="$3"
    local current_owner current_mode

    [[ -e "${dest}" ]] || return 1

    current_owner="$(stat -c '%U:%G' "${dest}")"
    current_mode="$(stat -c '%a' "${dest}")"
    [[ "${current_owner}" != "${owner}" || "${current_mode}" != "${mode}" ]]
}

apply_file_metadata() {
    local dest="$1"
    local owner="$2"
    local mode="$3"

    chown "${owner}" "${dest}"
    chmod "${mode}" "${dest}"
}

install_managed_file() {
    local src="$1"
    local dest="$2"
    local owner="${3:-root:root}"
    local mode
    local update_content=false

    if is_never_sync_path "${dest}"; then
        log_debug "Skipping never-sync path: ${dest}"
        return 0
    fi

    mode="$(mode_for_path "${dest}" "${src}")"
    if should_write_file "${src}" "${dest}"; then
        update_content=true
    fi

    if "${DRY_RUN}"; then
        if "${update_content}"; then
            log_info "Would install ${dest} (mode ${mode}, owner ${owner})"
        elif metadata_needs_update "${dest}" "${owner}" "${mode}"; then
            log_info "Would fix metadata for ${dest} (mode ${mode}, owner ${owner})"
        fi
        return 0
    fi

    if "${update_content}"; then
        ensure_parent_dir "${dest}" "${owner}"
        cp -f "${src}" "${dest}"
        log_info "Installed ${dest}"
    fi

    if [[ -e "${dest}" ]]; then
        if "${update_content}" || metadata_needs_update "${dest}" "${owner}" "${mode}"; then
            apply_file_metadata "${dest}" "${owner}" "${mode}"
            log_debug "Set metadata for ${dest} (mode ${mode}, owner ${owner})"
        fi
    fi
}

sync_tree_to_root() {
    local src rel dest

    while IFS= read -r -d '' src; do
        rel="${src#"${FILES_DIR}"/}"
        dest="/${rel}"

        # /etc/skel is synced as part of /etc, then also copied to existing homes
        # by sync_existing_home_dirs.
        install_managed_file "${src}" "${dest}"
    done < <(find "${FILES_DIR}" -type f -print0 | sort -z)

    if ! "${DRY_RUN}"; then
        [[ ! -d /etc/pnpm ]] || { chown root:root /etc/pnpm && chmod 755 /etc/pnpm; }
        [[ ! -d /etc/bun ]] || { chown root:root /etc/bun && chmod 755 /etc/bun; }
        [[ ! -d /root/.config ]] || { chown root:root /root/.config && chmod 700 /root/.config; }
        [[ ! -d /root/.config/pnpm ]] || { chown root:root /root/.config/pnpm && chmod 700 /root/.config/pnpm; }
        [[ ! -d /etc/skel/.config ]] || { chown root:root /etc/skel/.config && chmod 700 /etc/skel/.config; }
        [[ ! -d /etc/skel/.config/pnpm ]] || { chown root:root /etc/skel/.config/pnpm && chmod 700 /etc/skel/.config/pnpm; }
        [[ ! -d /etc/skel/.config/lsd ]] || { chown root:root /etc/skel/.config/lsd && chmod 700 /etc/skel/.config/lsd; }
        [[ ! -d /scripts ]] || { chown root:root /scripts && chmod 755 /scripts; }
    fi
}

sync_existing_home_dirs() {
    local skel_dir="${FILES_DIR}/etc/skel"
    local user_dir src rel dest owner

    require_dir "${skel_dir}"
    for user_dir in /home/*; do
        [[ -d "${user_dir}" ]] || continue
        [[ "$(basename -- "${user_dir}")" != 'lost+found' ]] || continue

        owner="$(stat -c '%U:%G' "${user_dir}")"
        log_info "Syncing ${skel_dir} to ${user_dir}..."

        while IFS= read -r -d '' src; do
            rel="${src#"${skel_dir}"/}"
            dest="${user_dir}/${rel}"
            install_managed_file "${src}" "${dest}" "${owner}"
        done < <(find "${skel_dir}" -type f -print0 | sort -z)

        if ! "${DRY_RUN}"; then
            [[ ! -d "${user_dir}/.config" ]] || { chown "${owner}" "${user_dir}/.config" && chmod 700 "${user_dir}/.config"; }
            [[ ! -d "${user_dir}/.config/pnpm" ]] || { chown "${owner}" "${user_dir}/.config/pnpm" && chmod 700 "${user_dir}/.config/pnpm"; }
            [[ ! -d "${user_dir}/.config/lsd" ]] || { chown "${owner}" "${user_dir}/.config/lsd" && chmod 700 "${user_dir}/.config/lsd"; }
        fi
    done
}

log_info "Syncing bootstrap-managed files from ${FILES_DIR}..."
sync_tree_to_root

if "${SYNC_HOME_DIRS}"; then
    sync_existing_home_dirs
else
    log_info 'Skipping existing home directories (--no-home-sync).'
fi

log_success 'Bootstrap-managed file sync complete.'
