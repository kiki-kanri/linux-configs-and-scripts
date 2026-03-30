# -*- mode: bash; tab-size: 4; -*-
# backup.sh — Backup an existing file before overwriting
#
# Usage:
#   backup_file /etc/nginx/nginx.conf    # backs up to /etc/nginx/nginx.conf.bak
#   backup_dir  /etc/nginx               # backs up entire dir
#
#   backup_file /path/to/file SKIP      # returns 0 but skips if already backed up this run
#   backup_file /path/to/file CHECK     # only backup if file exists
#
# The backup is named: <path>.<YYYYMMDD>.bak

_backup_timestamp() {
    date '+%Y%m%d%H%M%S'
}

# Backup a single file before modifying it.
# Returns 0 if backed up (or didn't need backup), non-zero on error.
backup_file() {
    local src="$1"
    local mode="${2:-OVERWRITE}" # OVERWRITE | SKIP | CHECK

    # CHECK mode: only backup if file exists
    if [[ "${mode}" == "CHECK" ]] && [[ ! -e "${src}" ]]; then
        return 0
    fi

    if [[ ! -e "${src}" ]]; then
        # File doesn't exist — nothing to backup
        return 0
    fi

    local backup="${src}.$(_backup_timestamp).bak"

    if [[ -e "${backup}" ]]; then
        # Already backed up this second (rare, shouldn't happen in normal use)
        return 0
    fi

    if ! cp -a "${src}" "${backup}"; then
        echo "ERROR: Failed to backup ${src} to ${backup}" >&2
        return 1
    fi

    echo "Backed up: ${src} -> ${backup}"
    return 0
}

# Backup a directory recursively.
backup_dir() {
    local src="$1"
    local backup="${src}.$(_backup_timestamp).bak"

    if [[ ! -e "${src}" ]]; then
        return 0
    fi

    if [[ -e "${backup}" ]]; then
        return 0
    fi

    if ! cp -a "${src}" "${backup}"; then
        echo "ERROR: Failed to backup directory ${src} to ${backup}" >&2
        return 1
    fi

    echo "Backed up directory: ${src} -> ${backup}"
    return 0
}
