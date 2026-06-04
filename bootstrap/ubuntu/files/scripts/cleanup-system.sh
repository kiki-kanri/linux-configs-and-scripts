#!/usr/bin/env bash
# Clean package, system, user, developer and selected Docker caches on Ubuntu.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/libs/common.sh"

DRY_RUN=0

usage() {
    cat <<USAGE
Usage: sudo $0 [--dry-run]

Options:
  --dry-run    Print cleanup actions without removing files.
  -h, --help   Show this help.

Developer caches are always removed: Cargo index/git cache and Go module cache.
USAGE
}

parse_args() {
    local arg

    for arg in "$@"; do
        case "${arg}" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: ${arg}"
            usage >&2
            exit 2
            ;;
        esac
    done
}

section() {
    printf '\n'
    log_info "== $* =="
}

log_plain() {
    log_info "$*"
}

log_dry_run() {
    log_warn "[DRY-RUN] $*"
}

run_cmd() {
    local status
    local tmp

    if ((DRY_RUN == 1)); then
        log_dry_run "$*"
        return 0
    fi

    tmp="$(mktemp)"
    if "$@" >"${tmp}" 2>&1; then
        log_success "$*"
        rm -f "${tmp}"
        return 0
    fi

    status=$?
    log_error "$*"
    sed 's/^/  /' "${tmp}" >&2
    rm -f "${tmp}"
    return "${status}"
}

rm_rf() {
    local path

    for path in "$@"; do
        if ((DRY_RUN == 1)); then
            log_dry_run "rm -rf -- ${path}"
        else
            rm -rf -- "${path}"
        fi
    done
}

empty_dir_contents() {
    local dir="$1"

    [[ -d "${dir}" ]] || return 0

    if ((DRY_RUN == 1)); then
        log_dry_run "empty contents of ${dir}"
        return 0
    fi

    find "${dir}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

empty_apt_lists() {
    if ((DRY_RUN == 1)); then
        log_dry_run "empty /var/lib/apt/lists except lock and partial"
        return 0
    fi

    find /var/lib/apt/lists -mindepth 1 -maxdepth 1 \
        ! -name lock \
        ! -name partial \
        -exec rm -rf -- {} +
}

snap_output() {
    if command_exists timeout; then
        timeout 10s snap list --all 2>/dev/null
    else
        snap list --all 2>/dev/null
    fi
}

cleanup_system() {
    section "System cleanup"

    run_cmd apt-get autoremove --purge -y
    run_cmd apt-get autoclean -y
    run_cmd apt-get clean

    if command_exists journalctl; then
        run_cmd journalctl --vacuum-time=7d
    fi

    rm_rf \
        /var/cache/apt/archives/*.deb \
        /var/cache/apt/archives/partial/* \
        /var/cache/apt/*.bin \
        /var/cache/debconf/*-old \
        /var/cache/man/* \
        /var/cache/fontconfig/* \
        /var/cache/ldconfig/* \
        /var/cache/swcatalog/* \
        /var/cache/app-info/* \
        /var/cache/fwupd/* \
        /var/lib/dpkg/*-old \
        /var/lib/fwupd/remotes.d/*/metadata.xml.gz \
        /var/lib/PackageKit/* \
        /var/lib/systemd/coredump/* \
        /var/log/*.gz \
        /var/log/*.[0-9] \
        /var/log/*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9] \
        /var/log/docker-build-*.log \
        /var/backups/*.bak \
        /var/tmp/* \
        /var/crash/*

    empty_apt_lists
    run_cmd install -d -m 755 /var/cache/apt/archives/partial /var/lib/apt/lists/partial

    empty_dir_contents /tmp
}

cleanup_snap() {
    local old_snaps
    local revision
    local snap_list
    local snap_name

    section "Snap cleanup"

    if ! command_exists snap; then
        log_plain "Snap not found, skip."
        return 0
    fi

    if ! snap_list="$(snap_output)"; then
        log_warn "snap list failed or timed out, skip."
        return 0
    fi

    old_snaps="$(awk '/disabled/{print $1, $3}' <<<"${snap_list}")"
    if [[ -z "${old_snaps}" ]]; then
        log_plain "No disabled snap revisions."
        return 0
    fi

    while read -r snap_name revision; do
        [[ -n "${snap_name}" && -n "${revision}" ]] || continue
        if ((DRY_RUN == 1)); then
            log_dry_run "snap remove ${snap_name} --revision=${revision}"
        else
            run_cmd snap remove "${snap_name}" --revision="${revision}" || true
        fi
    done <<<"${old_snaps}"
}

cleanup_flatpak() {
    section "Flatpak cleanup"

    if command_exists flatpak; then
        run_cmd flatpak uninstall --unused -y
    else
        log_plain "Flatpak not found, skip."
    fi
}

home_owner() {
    local home_dir="$1"

    stat -c '%U' "${home_dir}" 2>/dev/null || basename -- "${home_dir}"
}

cleanup_home_dir() {
    local home_dir="$1"
    local owner
    local path

    [[ -d "${home_dir}" ]] || return 0

    log_plain "Cleaning ${home_dir}"

    empty_dir_contents "${home_dir}/.thumbnails"
    rm_rf \
        "${home_dir}/.android" \
        "${home_dir}/.bun/install/cache" \
        "${home_dir}/.cache/baloo" \
        "${home_dir}/.cache/bazel" \
        "${home_dir}/.cache/buf" \
        "${home_dir}/.cache/buildkit" \
        "${home_dir}/.cache/cargo-zigbuild" \
        "${home_dir}/.cache/ccache" \
        "${home_dir}/.cache/chrome-remote-desktop" \
        "${home_dir}/.cache/chromium/Default/Cache" \
        "${home_dir}/.cache/cmake" \
        "${home_dir}/.cache/Code" \
        "${home_dir}/.cache/Cypress" \
        "${home_dir}/.cache/dconf" \
        "${home_dir}/.cache/deno" \
        "${home_dir}/.cache/discord" \
        "${home_dir}/.cache/electron" \
        "${home_dir}/.cache/evolution" \
        "${home_dir}/.cache/fontconfig" \
        "${home_dir}/.cache/gnome-software" \
        "${home_dir}/.cache/go-build" \
        "${home_dir}/.cache/google-chrome/Default/Cache" \
        "${home_dir}/.cache/Google" \
        "${home_dir}/.cache/huggingface" \
        "${home_dir}/.cache/ibus" \
        "${home_dir}/.cache/JetBrains" \
        "${home_dir}/.cache/JNA" \
        "${home_dir}/.cache/kioexec" \
        "${home_dir}/.cache/libreoffice" \
        "${home_dir}/.cache/lutris" \
        "${home_dir}/.cache/lxqt" \
        "${home_dir}/.cache/mesa" \
        "${home_dir}/.cache/mesa_shader_cache" \
        "${home_dir}/.cache/mesa_shader_cache_db" \
        "${home_dir}/.cache/Microsoft" \
        "${home_dir}/.cache/motd.legal-displayed" \
        "${home_dir}/.cache/mypy" \
        "${home_dir}/.cache/node-gyp" \
        "${home_dir}/.cache/npm" \
        "${home_dir}/.cache/nvidia" \
        "${home_dir}/.cache/openbox" \
        "${home_dir}/.cache/opera" \
        "${home_dir}/.cache/pdm" \
        "${home_dir}/.cache/pip" \
        "${home_dir}/.cache/pip-tools" \
        "${home_dir}/.cache/pnpm" \
        "${home_dir}/.cache/poetry" \
        "${home_dir}/.cache/pre-commit" \
        "${home_dir}/.cache/puppeteer" \
        "${home_dir}/.cache/pytest" \
        "${home_dir}/.cache/pypoetry" \
        "${home_dir}/.cache/qtshadercache" \
        "${home_dir}/.cache/ruff" \
        "${home_dir}/.cache/rust-analyzer" \
        "${home_dir}/.cache/sccache" \
        "${home_dir}/.cache/selenium" \
        "${home_dir}/.cache/software-center" \
        "${home_dir}/.cache/thumbnails" \
        "${home_dir}/.cache/thunderbird" \
        "${home_dir}/.cache/torch" \
        "${home_dir}/.cache/tox" \
        "${home_dir}/.cache/tracker" \
        "${home_dir}/.cache/tracker3" \
        "${home_dir}/.cache/typescript" \
        "${home_dir}/.cache/update-manager-core" \
        "${home_dir}/.cache/uv" \
        "${home_dir}/.cache/virtualenv" \
        "${home_dir}/.cache/VSCodium" \
        "${home_dir}/.cache/vulkan" \
        "${home_dir}/.cache/wayland-errors" \
        "${home_dir}/.cache/wine" \
        "${home_dir}/.cache/xsession-errors" \
        "${home_dir}/.cache/xfce4" \
        "${home_dir}/.cache/yarn" \
        "${home_dir}/.cache/zig" \
        "${home_dir}/.cargo/git/checkouts" \
        "${home_dir}/.cargo/registry/cache" \
        "${home_dir}/.cargo/registry/src" \
        "${home_dir}/.composer/cache" \
        "${home_dir}/.docker/buildx" \
        "${home_dir}/.dotnet" \
        "${home_dir}/.gradle" \
        "${home_dir}/.lesshst" \
        "${home_dir}/.local/share/baloo" \
        "${home_dir}/.local/share/containers/cache" \
        "${home_dir}/.local/share/fish/fish_history" \
        "${home_dir}/.local/share/flatpak/repo/objects/tmp" \
        "${home_dir}/.local/share/flatpak/repo/tmp" \
        "${home_dir}/.local/share/gvfs-metadata" \
        "${home_dir}/.local/share/klipper/history2.lst" \
        "${home_dir}/.local/share/pnpm" \
        "${home_dir}/.local/share/recently-used.xbel" \
        "${home_dir}/.local/share/resourcefullib" \
        "${home_dir}/.local/share/Steam/appcache" \
        "${home_dir}/.local/share/Steam/logs" \
        "${home_dir}/.local/share/Trash" \
        "${home_dir}/.m2/repository/.cache" \
        "${home_dir}/.npm/_cacache" \
        "${home_dir}/.npm/_logs" \
        "${home_dir}/.npm/_npx" \
        "${home_dir}/.nv" \
        "${home_dir}/.pnpm-store" \
        "${home_dir}/.python_history" \
        "${home_dir}/.rustup/tmp" \
        "${home_dir}/.wget-hsts" \
        "${home_dir}/.yarn/cache" \
        "${home_dir}/go/pkg/mod/cache"

    for path in \
        "${home_dir}"/.cache/ksycoca5_* \
        "${home_dir}"/.cache/ksycoca6_* \
        "${home_dir}"/.cache/mozilla/firefox/*/cache2 \
        "${home_dir}"/.cache/plasma* \
        "${home_dir}"/.var/app/*/cache \
        "${home_dir}"/snap/*/common/.cache; do
        rm_rf "${path}"
    done

    # Browser caches only; do not delete profiles, cookies, or passwords.
    rm_rf \
        "${home_dir}/.cache/mozilla" \
        "${home_dir}/.cache/google-chrome" \
        "${home_dir}/.cache/chromium" \
        "${home_dir}/.cache/BraveSoftware" \
        "${home_dir}/.cache/microsoft-edge"

    log_plain "Cleaning developer caches in ${home_dir}"
    rm_rf \
        "${home_dir}/.cargo/registry/index" \
        "${home_dir}/.cargo/git" \
        "${home_dir}/.config/google-chrome-for-testing/Crash Reports"

    if command_exists go && [[ -d "${home_dir}/go/pkg/mod" ]]; then
        if command_exists sudo; then
            owner="$(home_owner "${home_dir}")"
            if ((DRY_RUN == 1)); then
                log_dry_run "sudo -u ${owner} env HOME=${home_dir} go clean -modcache"
            else
                run_cmd sudo -u "${owner}" env HOME="${home_dir}" go clean -modcache || true
            fi
        else
            log_warn "sudo not found; skip go module cache cleanup for ${home_dir}."
        fi
    fi

    log_success "Cleaned ${home_dir}"
}

cleanup_home_dirs() {
    local home_dir
    local homes=(/root)

    section "User home cleanup"

    for home_dir in /home/*; do
        [[ -d "${home_dir}" ]] && homes+=("${home_dir}")
    done

    for home_dir in "${homes[@]}"; do
        cleanup_home_dir "${home_dir}"
    done
}

cleanup_docker_builder() {
    section "Docker builder cleanup"

    if ! command_exists docker; then
        log_plain "Docker not found, skip."
        return 0
    fi

    log_plain "Docker detected."
    run_cmd docker builder prune -af
    log_plain "Only Docker builder cache is cleaned automatically; images and volumes are left untouched."
    log_plain "To clean them manually, run: sudo docker system prune -a / sudo docker volume prune"
}

main() {
    parse_args "$@"
    require_root
    require_cmd apt-get df find id install mktemp rm sed stat

    section "Ubuntu cleanup started"
    log_plain "Dry run: ${DRY_RUN}"

    cleanup_system
    cleanup_snap
    cleanup_flatpak
    cleanup_home_dirs
    cleanup_docker_builder

    section "Disk usage after cleanup"
    df -h /

    section "Cleanup finished"
}

main "$@"
