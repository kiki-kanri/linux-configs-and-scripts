# -*- mode: bash; tab-size: 4; -*-
# require-cmd.sh — Check that one or more required commands exist
#
# Usage:
#   require_cmd curl jq          # exits 1 if either missing
#   require_cmd -e curl          # same, explicit -e flag (ignored, always exits)
#   require_cmd --optional curl  # logs warning but doesn't exit if missing
#
#   if require_cmd curl jq; then
#       echo "all present"
#   fi

require_cmd() {
    local optional=false
    local missing=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -e | --optional) optional=true ;;
        -*) ;; # ignore unknown flags
        *)
            if ! command -v "$1" >/dev/null 2>&1; then
                missing+=("$1")
            fi
            ;;
        esac
        shift
    done

    if ((${#missing[@]} > 0)); then
        if "${optional}"; then
            echo "WARNING: Commands not found: ${missing[*]}" >&2
            return 1
        else
            echo "ERROR: Required commands not found: ${missing[*]}" >&2
            echo "Install them and try again." >&2
            exit 1
        fi
    fi

    return 0
}
