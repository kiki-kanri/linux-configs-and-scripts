#!/usr/bin/env bash

# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Constants/Variables
readonly RESTIC_IMAGE='restic/restic:0.19.1'
readonly RETENTION=(
    --keep-within 2d
    --keep-daily 14
    --keep-weekly 8
    --keep-monthly 6
)

# Functions

# Deployed with the stack and run on its host, so the shared log library is not available.
log_info() {
    printf '[INFO] %s\n' "$*"
}

log_success() {
    printf '[ OK ] %s\n' "$*"
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

# Opens the repository directly on disk with the password add-user.sh saved for it.
run_restic() {
    local repository_name="$1"
    shift

    # --mount fails when the password file is missing, unlike -v which would create a directory in its place.
    docker run --rm \
        --mount "type=bind,src=${SCRIPT_DIR}/repository-passwords/${repository_name},dst=/repository-password,readonly" \
        --mount "type=bind,src=${SCRIPT_DIR}/data,dst=/data" \
        --mount "type=bind,src=${SCRIPT_DIR}/cache,dst=/root/.cache/restic" \
        -e RESTIC_PASSWORD_FILE=/repository-password \
        -e "RESTIC_REPOSITORY=/data/${repository_name}" \
        "${RESTIC_IMAGE}" \
        --retry-lock=1h \
        "$@"
}

# Run
main() {
    local check_subset=''
    local failures=0
    local repository_dir
    local repository_name

    # Read a different quarter of the data every Sunday, so all data is verified every four weeks.
    if [[ "$(date +%u)" == '7' ]]; then
        check_subset="$((10#$(date +%V) % 4 + 1))/4"
    fi

    mkdir -p -- "${SCRIPT_DIR}/cache"

    for repository_dir in "${SCRIPT_DIR}/data"/*/; do
        [[ -f "${repository_dir}config" ]] || continue
        repository_name="$(basename -- "${repository_dir}")"
        if [[ ! -f "${SCRIPT_DIR}/repository-passwords/${repository_name}" ]]; then
            log_error "No repository password for ${repository_name}; was it created with add-user.sh?"
            failures=$((failures + 1))
            continue
        fi

        # Group by host like the clients do, since expanded glob targets change the path list between snapshots.
        log_info "Pruning ${repository_name}..."
        if ! run_restic "${repository_name}" forget --group-by host "${RETENTION[@]}" --prune; then
            log_error "Failed to prune ${repository_name}"
            failures=$((failures + 1))
            continue
        fi

        if [[ -n "${check_subset}" ]]; then
            log_info "Checking ${repository_name} (${check_subset} of the data)..."
            if ! run_restic "${repository_name}" check "--read-data-subset=${check_subset}"; then
                log_error "Check failed for ${repository_name}"
                failures=$((failures + 1))
            fi
        fi
    done

    if ((failures > 0)); then
        log_error "${failures} repository operation(s) failed"
        exit 1
    fi

    log_success 'All repositories pruned'
}

main "$@"
